import 'dart:async';
import 'dart:typed_data';

import '../core/world_client_base.dart';
import '../events/wow_event.dart';
import '../models/player_info.dart';
import '../opcodes/opcodes.dart';
import '../packets/client/ping.dart';
import '../packets/client/ready_for_account_data_times.dart';
import '../packets/client/time_sync_resp.dart';
import '../packets/server/channel_notify.dart';
import '../packets/server/chat_not_in_party.dart';
import '../packets/server/chat_player_not_found.dart';
import '../packets/server/chat_restricted.dart';
import '../packets/server/chat_server_message.dart';
import '../packets/server/guild_command_result.dart';
import '../packets/server/guild_event.dart';
import '../packets/server/guild_roster.dart';
import '../packets/server/message_chat.dart';
import '../packets/server/motd.dart';
import '../packets/server/name_query_response.dart';
import '../packets/server/pong.dart';
import '../packets/server/who.dart';
import 'chat_mixin.dart';

/// Mixin providing the main session loop: ping keepalive + incoming packet dispatch.
mixin SessionMixin on WorldClientBase, ChatMixin {
  /// Keep the session alive with periodic PING packets and dispatch all
  /// incoming server packets.
  ///
  /// Returns a Future that completes when the connection is closed.
  Future<void> keepSessionAlive({
    Duration pingInterval = const Duration(seconds: 30),
    Function(String opcodeName, int opcodeValue, Uint8List payload)?
        onPacketReceived,
  }) async {
    int pingCounter = 0;
    Timer? pingTimer;
    final buffer = <int>[];
    bool isAlive = true;

    pingTimer = Timer.periodic(pingInterval, (timer) {
      if (!isAlive) {
        timer.cancel();
        return;
      }
      pingCounter++;
      try {
        sendEncrypted(
          PingPacket(pingValue: pingCounter, latency: 0).buildClientPacket(),
        );
        if (verbose) print('[WorldClient] Sent CMSG_PING (#$pingCounter)');
      } catch (e) {
        if (verbose) print('[WorldClient] Error sending PING: $e');
        timer.cancel();
        isAlive = false;
      }
    });

    final completer = Completer<void>();

    transport.dataStream.listen(
      (data) async {
        buffer.addAll(data);

        while (buffer.length >= 4 && isAlive) {
          final header = Uint8List.fromList(buffer.sublist(0, 4));
          authCrypt!.decryptRecv(header);

          final size = (header[0] << 8) | header[1];
          final opcode = header[2] | (header[3] << 8);

          final totalSize = 4 + size - 2;
          if (buffer.length < totalSize) break;

          final fullPacket = Uint8List.fromList(buffer.sublist(0, totalSize));
          final payload = Uint8List.fromList(buffer.sublist(4, totalSize));
          buffer.removeRange(0, totalSize);

          final opcodeName = getOpcodeName(opcode);

          if (opcode == ServerOpcode.SMSG_PONG.value) {
            try {
              final pong = PongPacket.parse(fullPacket);
              if (verbose) print('[WorldClient] Received SMSG_PONG (ping: ${pong.pingValue})');
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing PONG: $e');
            }
          } else if (opcode == ServerOpcode.SMSG_MESSAGECHAT.value) {
            try {
              final chatMessage = MessageChatReceivedPacket();
              chatMessage.parse(payload);
              await displayChatMessage(chatMessage);
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_MESSAGECHAT: $e');
            }
          } else if (opcode == ServerOpcode.SMSG_NAME_QUERY_RESPONSE.value) {
            try {
              final nameQueryResp = NameQueryResponsePacket();
              nameQueryResp.parse(payload);

              if (!nameQueryResp.nameUnknown && nameQueryResp.name != null) {
                final playerInfo = PlayerInfo(
                  guid: nameQueryResp.guid,
                  name: nameQueryResp.name!,
                  race: nameQueryResp.race ?? 0,
                  gender: nameQueryResp.gender ?? 0,
                  classId: nameQueryResp.classId ?? 0,
                  realmName: nameQueryResp.realmName,
                );
                nameCache[nameQueryResp.guid] = playerInfo;
                if (verbose) {
                  print('[WorldClient] Cached player name: ${nameQueryResp.name} (GUID: 0x${nameQueryResp.guid.toRadixString(16)})');
                }
                final pending = pendingNameQueries.remove(nameQueryResp.guid);
                pending?.complete(playerInfo);
              } else {
                final pending = pendingNameQueries.remove(nameQueryResp.guid);
                pending?.completeError('Player not found');
              }
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_NAME_QUERY_RESPONSE: $e');
            }
          } else if (opcode == ServerOpcode.SMSG_CHAT_PLAYER_NOT_FOUND.value) {
            try {
              final errorPacket = ChatPlayerNotFoundPacket();
              errorPacket.parse(payload);
              emitEvent(ServerMessageEvent(
                messageType: 'Chat Error',
                message: 'No hay un jugador con el nombre "${errorPacket.playerName}"',
              ));
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_CHAT_PLAYER_NOT_FOUND: $e');
            }
          } else if (opcode == ServerOpcode.SMSG_CHAT_WRONG_FACTION.value) {
            emitEvent(ServerMessageEvent(
              messageType: 'Chat Error',
              message: 'No puedes chatear con jugadores de la facción enemiga',
            ));
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else if (opcode == ServerOpcode.SMSG_CHAT_RESTRICTED.value) {
            try {
              final errorPacket = ChatRestrictedPacket();
              errorPacket.parse(payload);
              emitEvent(ServerMessageEvent(
                messageType: 'Chat Error',
                message: errorPacket.restrictionMessage,
              ));
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              emitEvent(ServerMessageEvent(
                messageType: 'Chat Error',
                message: 'Tu chat está restringido',
              ));
            }
          } else if (opcode == ServerOpcode.SMSG_CHAT_NOT_IN_PARTY.value) {
            try {
              final errorPacket = ChatNotInPartyPacket();
              errorPacket.parse(payload);
              emitEvent(ServerMessageEvent(
                messageType: 'Chat Error',
                message: errorPacket.errorMessage,
              ));
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              emitEvent(ServerMessageEvent(
                messageType: 'Chat Error',
                message: 'No estás en un grupo',
              ));
            }
          } else if (opcode == ServerOpcode.SMSG_GUILD_COMMAND_RESULT.value) {
            try {
              final guildResult = GuildCommandResultPacket();
              guildResult.parse(payload);
              if (guildResult.result != 0) {
                emitEvent(ServerMessageEvent(
                  messageType: 'Guild Error',
                  message: guildResult.errorMessage,
                ));
              }
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_GUILD_COMMAND_RESULT: $e');
            }
          } else if (opcode == ServerOpcode.SMSG_WHO.value) {
            try {
              final whoResponse = WhoResponsePacket.parse(payload);
              if (verbose) {
                print('[WorldClient] Received SMSG_WHO: ${whoResponse.players.length} players (total: ${whoResponse.totalCount})');
                for (final player in whoResponse.players) {
                  print('  - $player');
                }
              }
              emitEvent(WhoResponseEvent(
                players: whoResponse.players,
                totalCount: whoResponse.totalCount,
              ));
              if (pendingWhoRequest != null && !pendingWhoRequest!.isCompleted) {
                pendingWhoRequest!.complete(whoResponse.players);
                pendingWhoRequest = null;
              }
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_WHO: $e');
              if (pendingWhoRequest != null && !pendingWhoRequest!.isCompleted) {
                pendingWhoRequest!.complete(<WhoPlayerInfo>[]);
                pendingWhoRequest = null;
              }
            }
          } else if (opcode == ServerOpcode.SMSG_CHAT_SERVER_MESSAGE.value) {
            if (verbose) print('[WorldClient] Received SMSG_CHAT_SERVER_MESSAGE (${payload.length} bytes)');
            try {
              final serverMessage = ChatServerMessagePacket.parse(payload);
              emitEvent(ServerMessageEvent(
                messageType: serverMessage.messageType.displayName,
                message: serverMessage.message,
              ));
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) {
                print('[WorldClient] Error parsing SMSG_CHAT_SERVER_MESSAGE: $e');
                if (payload.isNotEmpty) {
                  final hex = payload.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                  print('[WorldClient] Payload (first 20 bytes): $hex');
                }
              }
            }
          } else if (opcode == ServerOpcode.SMSG_MOTD.value) {
            if (verbose) print('[WorldClient] Received SMSG_MOTD (${payload.length} bytes)');
            try {
              final motd = MotdPacket.parse(payload);
              if (motd.lines.isNotEmpty) {
                emitEvent(MotdEvent(motd.lines));
              } else if (verbose) {
                print('[WorldClient] MOTD is empty');
              }
              onPacketReceived?.call(opcodeName, opcode, payload);
            } catch (e) {
              if (verbose) {
                print('[WorldClient] Error parsing SMSG_MOTD: $e');
                if (payload.isNotEmpty) {
                  final hex = payload.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                  print('[WorldClient] MOTD payload (first 20 bytes): $hex');
                }
              }
            }
          } else if (opcode == ServerOpcode.SMSG_ACCOUNT_DATA_TIMES.value) {
            if (verbose) print('[WorldClient] Received SMSG_ACCOUNT_DATA_TIMES, sending ready response');
            try {
              sendEncrypted(ReadyForAccountDataTimesPacket().buildClientPacket());
              if (verbose) print('[WorldClient] Sent CMSG_READY_FOR_ACCOUNT_DATA_TIMES');
            } catch (e) {
              if (verbose) print('[WorldClient] Error sending READY_FOR_ACCOUNT_DATA_TIMES: $e');
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else if (opcode == ServerOpcode.SMSG_TIME_SYNC_REQ.value) {
            if (payload.length >= 4) {
              try {
                final counter =
                    ByteData.sublistView(payload, 0, 4).getUint32(0, Endian.little);
                final ticks = DateTime.now().millisecondsSinceEpoch;
                sendEncrypted(
                  TimeSyncRespPacket(counter: counter, ticks: ticks).buildClientPacket(),
                );
                if (verbose) {
                  print('[WorldClient] Sent CMSG_TIME_SYNC_RESP (counter: $counter, ticks: $ticks)');
                }
              } catch (e) {
                if (verbose) print('[WorldClient] Error sending TIME_SYNC_RESP: $e');
              }
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else if (opcode == ServerOpcode.SMSG_CHANNEL_NOTIFY.value) {
            try {
              final notify = ChannelNotifyPacket.parse(payload);
              if (notify != null) {
                emitEvent(ChannelNotifyEvent(notify.displayMessage));
              }
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_CHANNEL_NOTIFY: $e');
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else if (opcode == ServerOpcode.SMSG_GUILD_EVENT.value) {
            try {
              final event = GuildEventPacket.parse(payload);
              if (event != null) {
                final msg = event.displayMessage;
                if (msg.isNotEmpty) emitEvent(GuildEvent(msg));
              }
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_GUILD_EVENT: $e');
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else if (opcode == ServerOpcode.SMSG_GUILD_ROSTER.value) {
            try {
              final roster = GuildRosterPacket.parse(payload);
              if (roster != null) {
                guildMembers = roster.members;
                emitEvent(GuildRosterUpdatedEvent(roster.members));
                if (pendingGuildRoster != null && !pendingGuildRoster!.isCompleted) {
                  pendingGuildRoster!.complete(roster.members);
                  pendingGuildRoster = null;
                }
              }
            } catch (e) {
              if (verbose) print('[WorldClient] Error parsing SMSG_GUILD_ROSTER: $e');
              if (pendingGuildRoster != null && !pendingGuildRoster!.isCompleted) {
                pendingGuildRoster!.complete(<GuildMemberInfo>[]);
                pendingGuildRoster = null;
              }
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          } else {
            if (verbose && !opcodeName.startsWith('UNKNOWN')) {
              print('[WorldClient] Received: $opcodeName (0x${opcode.toRadixString(16).padLeft(4, '0')}) - ${payload.length} bytes');
            }
            onPacketReceived?.call(opcodeName, opcode, payload);
          }
        }
      },
      onError: (error) {
        if (verbose) print('[WorldClient] Socket error: $error');
        isAlive = false;
        pingTimer?.cancel();
        emitEvent(ConnectionErrorEvent(error));
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        if (verbose) print('[WorldClient] Connection closed');
        isAlive = false;
        pingTimer?.cancel();
        emitEvent(ConnectionClosedEvent());
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }
}
