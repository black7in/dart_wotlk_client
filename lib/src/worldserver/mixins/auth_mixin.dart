import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../transport/tcp_transport.dart';
import '../auth_crypt.dart';
import '../auth_utils.dart';
import '../core/world_client_base.dart';
import '../models/world_auth_result.dart';
import '../models/world_connection_result.dart';
import '../packets/client/auth_session.dart';
import '../packets/client/char_enum.dart';
import '../packets/server/auth_challenge.dart';
import '../packets/server/auth_response.dart';
import '../packets/server/char_enum.dart';
import '../opcodes/opcodes.dart';

/// Zero-addon info block: size field = 0 tells the server to skip addon processing.
Uint8List _createEmptyAddonInfo() => Uint8List(4);

/// Mixin providing world server authentication and character enumeration.
mixin AuthMixin on WorldClientBase {
  /// Authenticate with the world server (SMSG_AUTH_CHALLENGE → CMSG_AUTH_SESSION → SMSG_AUTH_RESPONSE).
  ///
  /// On success, [authCrypt] is initialised in the base and the transport
  /// remains connected for subsequent calls.
  Future<WorldAuthResult> authenticate({
    required String accountName,
    required Uint8List sessionKey,
    required int realmId,
    int build = 12340,
    Duration? connectionDelay,
  }) async {
    try {
      if (verbose) print('[WorldClient] Connecting to ${transport.host}:${transport.port}...');
      await transport.connect();
      if (verbose) print('[WorldClient] Connected!');

      final completer = Completer<WorldAuthResult>();
      final buffer = <int>[];
      bool challengeReceived = false;
      bool authSent = false;
      final crypt = AuthCrypt();

      transport.dataStream.listen(
        (data) async {
          buffer.addAll(data);
          if (verbose) debugPrintPacket('recv', data);

          if (!challengeReceived && buffer.length >= 44) {
            final challenge = AuthChallengePacket.parse(buffer);
            if (challenge != null) {
              buffer.removeRange(0, AuthChallengePacket.getConsumedBytes(buffer));
              challengeReceived = true;
              if (verbose) {
                print('[WorldClient] Received AUTH_CHALLENGE');
                print('  Challenge number: ${challenge.challengeNumber}');
                print('  Auth seed: ${toHex(challenge.authSeed)}');
              }

              final random = Random.secure();
              final localChallenge = Uint8List(4);
              for (int i = 0; i < 4; i++) localChallenge[i] = random.nextInt(256);
              if (verbose) print('  Local challenge: ${toHex(localChallenge)}');

              final accountNameUpper = accountName.toUpperCase();
              final digest = calculateAuthDigest(
                accountName: accountNameUpper,
                localChallenge: localChallenge,
                authSeed: challenge.authSeed,
                sessionKey: sessionKey,
              );
              if (verbose) print('  Digest: ${toHex(digest)}');

              final authSession = AuthSessionPacket(
                build: build,
                loginServerID: 0,
                accountName: accountNameUpper,
                loginServerType: 0,
                localChallenge: localChallenge,
                regionID: 1,
                battlegroupID: 1,
                realmID: realmId,
                dosResponse: 0,
                digest: digest,
                addonInfo: _createEmptyAddonInfo(),
              );

              final authBytes = authSession.buildClientPacket();
              if (verbose) {
                debugPrintPacket('send', authBytes);
                print('[WorldClient] Sent AUTH_SESSION');
              }

              transport.send(authBytes);
              if (transport is TcpTransport) await (transport as TcpTransport).flush();
              authSent = true;
              crypt.init(sessionKey);
              if (verbose) print('[WorldClient] Header encryption initialized');
            }
          }

          if (authSent && buffer.length >= 4) {
            final encryptedHeader = Uint8List.fromList(buffer.sublist(0, 4));
            crypt.decryptRecv(encryptedHeader);
            final size = (encryptedHeader[0] << 8) | encryptedHeader[1];
            final opcode = encryptedHeader[2] | (encryptedHeader[3] << 8);
            final totalPacketSize = 2 + size;

            if (buffer.length >= totalPacketSize) {
              for (int i = 0; i < 4; i++) buffer[i] = encryptedHeader[i];

              if (verbose) {
                print('[WorldClient] Decrypted header: ${toHex(encryptedHeader)}');
                print('  Opcode: 0x${opcode.toRadixString(16).padLeft(4, '0').toUpperCase()} (size: $size bytes)');
              }

              if (opcode == ServerOpcode.SMSG_AUTH_RESPONSE.value) {
                final response = AuthResponsePacket.parse(buffer);
                if (response != null) {
                  buffer.removeRange(0, AuthResponsePacket.getConsumedBytes(buffer));
                  if (verbose) {
                    print('[WorldClient] Received SMSG_AUTH_RESPONSE');
                    print('  Code: 0x${response.responseCode.toRadixString(16).padLeft(2, '0').toUpperCase()}');
                    print('  Message: ${response.message}');
                  }
                  if (!completer.isCompleted) {
                    if (response.isSuccess) {
                      authCrypt = crypt;
                      completer.complete(
                          WorldAuthResult.successResult('World server authentication successful'));
                    } else {
                      completer.complete(
                          WorldAuthResult.failure(response.responseCode, response.message));
                    }
                  }
                }
              } else {
                if (verbose) {
                  final opcodeName = getOpcodeName(opcode);
                  if (!opcodeName.startsWith('UNKNOWN')) {
                    print('[WorldClient] Skipping packet: $opcodeName');
                  }
                }
                buffer.removeRange(0, totalPacketSize);
              }
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(WorldAuthResult.failure(-1, 'Socket error: $e'));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(
                WorldAuthResult.failure(-1, 'Connection closed by server'));
          }
        },
      );

      await Future.delayed(connectionDelay ?? const Duration(milliseconds: 100));

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            WorldAuthResult.failure(-1, 'World server authentication timeout'),
      );

      if (!result.success) await transport.close();
      return result;
    } catch (e) {
      await transport.close();
      return WorldAuthResult.failure(-1, 'Connection error: $e');
    }
  }

  /// Authenticate with the world server AND retrieve the character list in one flow.
  Future<WorldConnectionResult> authenticateAndGetCharacters({
    required String accountName,
    required Uint8List sessionKey,
    required int realmId,
    int build = 12340,
    Duration? connectionDelay,
  }) async {
    try {
      if (verbose) print('[WorldClient] Connecting to ${transport.host}:${transport.port}...');
      await transport.connect();
      if (verbose) print('[WorldClient] Connected!');

      final completer = Completer<WorldConnectionResult>();
      final buffer = <int>[];
      bool challengeReceived = false;
      bool authSent = false;
      bool authSuccessful = false;
      bool charEnumSent = false;
      final crypt = AuthCrypt();

      StreamSubscription? streamSubscription;
      streamSubscription = transport.dataStream.listen(
        (data) {
          buffer.addAll(data);
          if (verbose) debugPrintPacket('recv', data);

          if (!challengeReceived && buffer.length >= 44) {
            final challenge = AuthChallengePacket.parse(buffer);
            if (challenge != null) {
              buffer.removeRange(0, AuthChallengePacket.getConsumedBytes(buffer));
              challengeReceived = true;
              if (verbose) {
                print('[WorldClient] Received AUTH_CHALLENGE');
                print('  Challenge number: ${challenge.challengeNumber}');
                print('  Auth seed: ${toHex(challenge.authSeed)}');
              }

              final random = Random.secure();
              final localChallenge = Uint8List(4);
              for (int i = 0; i < 4; i++) localChallenge[i] = random.nextInt(256);
              if (verbose) print('  Local challenge: ${toHex(localChallenge)}');

              final accountNameUpper = accountName.toUpperCase();
              final digest = calculateAuthDigest(
                accountName: accountNameUpper,
                localChallenge: localChallenge,
                authSeed: challenge.authSeed,
                sessionKey: sessionKey,
              );
              if (verbose) print('  Digest: ${toHex(digest)}');

              final authSession = AuthSessionPacket(
                build: build,
                loginServerID: 0,
                accountName: accountNameUpper,
                loginServerType: 0,
                localChallenge: localChallenge,
                regionID: 1,
                battlegroupID: 1,
                realmID: realmId,
                dosResponse: 0,
                digest: digest,
                addonInfo: _createEmptyAddonInfo(),
              );

              transport.send(authSession.buildClientPacket());
              // Fire-and-forget flush: no await to avoid async callback re-entrancy
              if (transport is TcpTransport) (transport as TcpTransport).flush();
              authSent = true;
              crypt.init(sessionKey);
              if (verbose) print('[WorldClient] Sent AUTH_SESSION');
            }
          }

          if (authSent && !completer.isCompleted) {
            while (buffer.length >= 4) {
              final headerBytes = Uint8List.fromList(buffer.sublist(0, 4));
              crypt.decryptRecv(headerBytes);
              buffer.replaceRange(0, 4, headerBytes);

              final size = (buffer[0] << 8) | buffer[1];
              final opcode = buffer[2] | (buffer[3] << 8);

              if (verbose) {
                print('[WorldClient] Decrypted header: ${toHex(Uint8List.fromList(buffer.sublist(0, 4)))}');
                print('  Opcode: 0x${opcode.toRadixString(16).padLeft(4, '0')} (size: $size bytes)');
              }

              final totalPacketSize = 4 + size - 2;
              if (buffer.length < totalPacketSize) {
                if (verbose) print('[WorldClient] Waiting for more data (have ${buffer.length}, need $totalPacketSize)');
                break;
              }

              final payload = Uint8List.fromList(buffer.sublist(4, totalPacketSize));

              if (opcode == ServerOpcode.SMSG_AUTH_RESPONSE.value) {
                final fullBuffer = buffer.sublist(0, totalPacketSize);
                final response = AuthResponsePacket.parse(fullBuffer);
                if (response != null) {
                  buffer.removeRange(0, AuthResponsePacket.getConsumedBytes(buffer));
                  if (verbose) {
                    print('[WorldClient] Received SMSG_AUTH_RESPONSE');
                    print('  Code: 0x${response.responseCode.toRadixString(16).padLeft(2, '0').toUpperCase()}');
                    print('  Message: ${response.message}');
                  }
                  if (response.isSuccess) {
                    authCrypt = crypt;
                    authSuccessful = true;
                    if (!charEnumSent) {
                      if (verbose) print('[WorldClient] Sending CMSG_CHAR_ENUM...');
                      sendEncrypted(CharEnumPacket().buildClientPacket());
                      if (transport is TcpTransport) (transport as TcpTransport).flush();
                      charEnumSent = true;
                    }
                  } else {
                    completer.complete(WorldConnectionResult.failure(
                        response.responseCode, response.message));
                  }
                }
              } else if (opcode == ServerOpcode.SMSG_CHAR_ENUM.value && authSuccessful) {
                if (verbose) print('[WorldClient] Received SMSG_CHAR_ENUM');
                final response = CharEnumResponse.parse(payload);
                if (response != null) {
                  if (verbose) print('[WorldClient] Parsed ${response.characters.length} characters');
                  buffer.removeRange(0, totalPacketSize);
                  streamSubscription?.cancel();
                  completer.complete(WorldConnectionResult.successResult(
                    message: 'Successfully authenticated and retrieved ${response.characters.length} character(s)',
                    characters: response.characters,
                  ));
                } else {
                  completer.complete(WorldConnectionResult.failure(
                      -1, 'Failed to parse character list'));
                }
              } else {
                if (verbose) {
                  final opcodeName = getOpcodeName(opcode);
                  if (!opcodeName.startsWith('UNKNOWN')) {
                    print('[WorldClient] Skipping packet: $opcodeName');
                  }
                }
                buffer.removeRange(0, totalPacketSize);
              }
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(WorldConnectionResult.failure(-1, 'Socket error: $e'));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(
                WorldConnectionResult.failure(-1, 'Connection closed by server'));
          }
        },
      );

      await Future.delayed(connectionDelay ?? const Duration(milliseconds: 100));

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            WorldConnectionResult.failure(-1, 'World server connection timeout'),
      );

      if (!result.success) await transport.close();
      return result;
    } catch (e) {
      await transport.close();
      return WorldConnectionResult.failure(-1, 'Connection error: $e');
    }
  }

  /// Request the character list from an already-authenticated connection.
  Future<List<CharacterData>?> getCharacterList({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (verbose) print('[WorldClient] Requesting character list...');

      sendEncrypted(CharEnumPacket().buildClientPacket());
      if (transport is TcpTransport) await (transport as TcpTransport).flush();
      if (verbose) print('[WorldClient] Sending CMSG_CHAR_ENUM');

      final buffer = <int>[];
      await for (final data in transport.dataStream.timeout(timeout)) {
        buffer.addAll(data);

        while (buffer.length >= 4) {
          final headerBytes = Uint8List.fromList(buffer.sublist(0, 4));
          authCrypt!.decryptRecv(headerBytes);
          buffer.replaceRange(0, 4, headerBytes);

          final size = (buffer[0] << 8) | buffer[1];
          final opcode = buffer[2] | (buffer[3] << 8);

          if (verbose) {
            print('[WorldClient] Decrypted header: ${toHex(Uint8List.fromList(buffer.sublist(0, 4)))}');
            print('  Opcode: 0x${opcode.toRadixString(16).padLeft(4, '0')} (size: $size bytes)');
          }

          final totalSize = 4 + size - 2;
          if (buffer.length < totalSize) {
            if (verbose) print('[WorldClient] Waiting for more data (have ${buffer.length}, need $totalSize)');
            break;
          }

          final payload = Uint8List.fromList(buffer.sublist(4, totalSize));
          buffer.removeRange(0, totalSize);

          if (opcode == ServerOpcode.SMSG_CHAR_ENUM.value) {
            if (verbose) print('[WorldClient] Received SMSG_CHAR_ENUM');
            final response = CharEnumResponse.parse(payload);
            if (response != null) {
              if (verbose) print('[WorldClient] Parsed ${response.characters.length} characters');
              return response.characters;
            }
            return null;
          } else {
            final opcodeName = getOpcodeName(opcode);
            if (verbose && !opcodeName.startsWith('UNKNOWN')) {
              print('[WorldClient] Skipping packet: $opcodeName');
            }
          }
        }
      }
      return null;
    } catch (e) {
      if (verbose) print('[WorldClient] Error getting character list: $e');
      return null;
    }
  }
}
