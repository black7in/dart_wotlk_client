import 'dart:async';
import 'dart:typed_data';

import '../../transport/tcp_transport.dart';
import '../core/world_client_base.dart';
import '../events/wow_event.dart';
import '../models/world_login_result.dart';
import '../opcodes/opcodes.dart';
import '../packets/client/move_worldport_ack.dart';
import '../packets/client/player_login.dart';
import '../packets/client/ready_for_account_data_times.dart';
import '../packets/server/account_data_times.dart';
import '../packets/server/guild_event.dart';
import '../packets/server/guild_roster.dart';
import '../packets/server/login_verify_world.dart';
import '../packets/server/motd.dart';
import '../packets/server/pong.dart';

/// Mixin providing the world login flow (CMSG_PLAYER_LOGIN through SMSG_MOTD).
mixin LoginMixin on WorldClientBase {
  /// Send CMSG_PLAYER_LOGIN and wait until the server completes its login
  /// initialization sequence (LOGIN_VERIFY_WORLD → ACCOUNT_DATA_TIMES → MOTD
  /// → guild events).
  Future<WorldLoginResult> loginToWorld({
    required int characterGuid,
  }) async {
    try {
      if (verbose) {
        print('\n═══════════════════════════════════════════════════');
        print('  LOGGING INTO WORLD');
        print('═══════════════════════════════════════════════════');
        print('Character GUID: $characterGuid');
      }

      sendEncrypted(PlayerLoginPacket(characterGuid: characterGuid).buildClientPacket());
      if (transport is TcpTransport) await (transport as TcpTransport).flush();
      if (verbose) print('[WorldClient] Sent CMSG_PLAYER_LOGIN');

      final buffer = <int>[];
      final completer = Completer<WorldLoginResult>();
      LoginVerifyWorldPacket? verifyWorldData;
      bool loginVerified = false;

      StreamSubscription? subscription;
      subscription = transport.dataStream.listen(
        (data) {
          buffer.addAll(data);

          while (buffer.length >= 4) {
            final header = Uint8List.fromList(buffer.sublist(0, 4));
            authCrypt!.decryptRecv(header);

            final size = (header[0] << 8) | header[1];
            final opcode = header[2] | (header[3] << 8);

            final opcodeName = getOpcodeName(opcode);
            if (verbose &&
                opcode != ServerOpcode.SMSG_PONG.value &&
                !opcodeName.startsWith('UNKNOWN')) {
              print('[WorldClient] Received opcode: 0x${opcode.toRadixString(16).padLeft(4, '0')} ($opcodeName) - size: $size bytes');
            }

            final totalSize = 4 + size - 2;
            if (buffer.length < totalSize) break;

            final fullPacket = Uint8List.fromList(buffer.sublist(0, totalSize));
            buffer.removeRange(0, totalSize);

            if (opcode == ServerOpcode.SMSG_LOGIN_VERIFY_WORLD.value) {
              if (verbose) print('[WorldClient] Received SMSG_LOGIN_VERIFY_WORLD');
              try {
                final parsedWorld = LoginVerifyWorldPacket.parse(fullPacket);
                verifyWorldData = parsedWorld;
                if (verbose) {
                  print('[WorldClient] Login verified!');
                  print('  Map: ${parsedWorld.mapName}');
                  print('  Position: (${parsedWorld.positionX.toStringAsFixed(2)}, ${parsedWorld.positionY.toStringAsFixed(2)}, ${parsedWorld.positionZ.toStringAsFixed(2)})');
                  print('  Orientation: ${parsedWorld.orientation.toStringAsFixed(2)}');
                }

                sendEncrypted(MoveWorldportAckPacket().buildClientPacket());
                if (verbose) print('[WorldClient] Sent CMSG_MOVE_WORLDPORT_ACK');

                loginVerified = true;

                // Fallback: complete after 2 s even if MOTD never arrives
                Future.delayed(const Duration(seconds: 2), () {
                  if (!completer.isCompleted) {
                    subscription?.cancel();
                    completer.complete(WorldLoginResult.success(
                      message: 'Successfully logged into world',
                      verifyWorld: verifyWorldData,
                    ));
                  }
                });
              } catch (e) {
                if (verbose) print('[WorldClient] Error parsing LOGIN_VERIFY_WORLD: $e');
              }
            } else if (opcode == ServerOpcode.SMSG_ACCOUNT_DATA_TIMES.value) {
              if (verbose) print('[WorldClient] Received SMSG_ACCOUNT_DATA_TIMES');
              try {
                final accountData = AccountDataTimesPacket.parse(fullPacket);
                if (verbose) {
                  print('  Timestamp: ${accountData.timestamp}');
                  print('  Mask: 0x${accountData.mask.toRadixString(16).padLeft(8, '0')}');
                }
                sendEncrypted(ReadyForAccountDataTimesPacket().buildClientPacket());
                if (verbose) print('[WorldClient] Sent CMSG_READY_FOR_ACCOUNT_DATA_TIMES');
              } catch (e) {
                if (verbose) print('[WorldClient] Error handling ACCOUNT_DATA_TIMES: $e');
              }
            } else if (opcode == ServerOpcode.SMSG_MOTD.value) {
              try {
                final payload = Uint8List.fromList(fullPacket.sublist(4));
                final motd = MotdPacket.parse(payload);
                if (motd.lines.isNotEmpty) {
                  emitEvent(MotdEvent(motd.lines));
                }
              } catch (e) {
                if (verbose) print('[WorldClient] Error parsing SMSG_MOTD: $e');
              }

              // Wait 500 ms after MOTD: the guild MOTD (SMSG_GUILD_EVENT GE_MOTD)
              // is sent by the server immediately after in the same login sequence.
              if (loginVerified && !completer.isCompleted) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!completer.isCompleted) {
                    subscription?.cancel();
                    completer.complete(WorldLoginResult.success(
                      message: 'Successfully logged into world',
                      verifyWorld: verifyWorldData,
                    ));
                  }
                });
              }
            } else if (opcode == ServerOpcode.SMSG_GUILD_EVENT.value) {
              try {
                final payload = Uint8List.fromList(fullPacket.sublist(4));
                final event = GuildEventPacket.parse(payload);
                if (event != null) {
                  final msg = event.displayMessage;
                  if (msg.isNotEmpty) emitEvent(GuildEvent(msg));
                }
              } catch (e) {
                if (verbose) print('[WorldClient] Error parsing SMSG_GUILD_EVENT (login): $e');
              }
            } else if (opcode == ServerOpcode.SMSG_GUILD_ROSTER.value) {
              try {
                final payload = Uint8List.fromList(fullPacket.sublist(4));
                final roster = GuildRosterPacket.parse(payload);
                if (roster != null) {
                  guildMembers = roster.members;
                  emitEvent(GuildRosterUpdatedEvent(roster.members));
                }
              } catch (e) {
                if (verbose) print('[WorldClient] Error parsing SMSG_GUILD_ROSTER (login): $e');
              }
            } else if (opcode == ServerOpcode.SMSG_PONG.value) {
              try {
                final pong = PongPacket.parse(fullPacket);
                if (verbose) print('[WorldClient] Received SMSG_PONG (ping: ${pong.pingValue})');
              } catch (e) {
                if (verbose) print('[WorldClient] Error parsing PONG: $e');
              }
            } else {
              if (verbose && !opcodeName.startsWith('UNKNOWN')) {
                print('[WorldClient] Received packet: $opcodeName (0x${opcode.toRadixString(16).padLeft(4, '0')})');
              }
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(WorldLoginResult.failure(
              errorCode: -1,
              message: 'Connection closed before login verification',
            ));
          }
        },
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          subscription?.cancel();
          return WorldLoginResult.failure(
            errorCode: -2,
            message: 'Login timeout - no LOGIN_VERIFY_WORLD received',
          );
        },
      );

      if (verbose) print('═══════════════════════════════════════════════════\n');
      return result;
    } catch (e) {
      if (verbose) print('[WorldClient] Login error: $e');
      return WorldLoginResult.failure(errorCode: -3, message: 'Login failed: $e');
    }
  }
}
