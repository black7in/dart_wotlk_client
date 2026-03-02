/// High-level WoW authentication client
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../constants.dart';
import '../crypto/srp6.dart';
import 'packets.dart';

/// Result of authentication attempt
class AuthResult {
  final bool success;
  final int errorCode;
  final String message;
  final Uint8List? sessionKey;
  final List<RealmInfo>? realms;

  AuthResult({
    required this.success,
    required this.errorCode,
    required this.message,
    this.sessionKey,
    this.realms,
  });

  factory AuthResult.success(Uint8List sessionKey, {List<RealmInfo>? realms}) {
    return AuthResult(
      success: true,
      errorCode: WOW_SUCCESS,
      message: 'Authentication successful',
      sessionKey: sessionKey,
      realms: realms,
    );
  }

  factory AuthResult.failure(int errorCode, String message) {
    return AuthResult(
      success: false,
      errorCode: errorCode,
      message: message,
    );
  }
}

/// WoW authentication client
class WowAuthClient {
  final String host;
  final int port;
  final bool verbose;

  WowAuthClient({
    required this.host,
    required this.port,
    this.verbose = false,
  });

  /// Connect and authenticate to the authserver
  Future<AuthResult> authenticate({
    required String username,
    required String password,
    Duration? connectionDelay,
    bool requestRealms = false, // Request realm list after successful auth
  }) async {
    Socket? socket;
    try {
      // Connect
      if (verbose) print('Connecting to $host:$port...');
      socket = await Socket.connect(host, port);
      if (verbose) print('Connected.');

      // Setup state for packet handling
      final buffer = <int>[];
      final completer = Completer<AuthResult>();

      bool challengeSent = false;
      bool proofSent = false;
      bool realmListSent = false;
      SRP6Result? srp;
      Uint8List? sessionKey;

      // Listen to socket data
      socket.listen(
        (data) async {
          buffer.addAll(data);

          if (verbose) {
            _debugPrintPacket('recv', data);
          }

          // Handle challenge response
          if (challengeSent && !proofSent) {
            final challengeResponse = AuthLogonChallengeResponse.parse(buffer);
            if (challengeResponse != null) {
              final consumed = AuthLogonChallengeResponse.getConsumedBytes(buffer);
              buffer.removeRange(0, consumed);

              if (!challengeResponse.isSuccess) {
                if (!completer.isCompleted) {
                  completer.complete(AuthResult.failure(
                    challengeResponse.result,
                    'Challenge failed: ${_errorCodeToString(challengeResponse.result)}',
                  ));
                }
                return;
              }

              if (verbose) {
                print('Received AUTH_LOGON_CHALLENGE: result=${challengeResponse.result}');
                print('B: ${_toHex(challengeResponse.B!)}');
                print('salt: ${_toHex(challengeResponse.salt!)}');
              }

              // Perform SRP6 calculations
              srp = computeSRP6(
                username: username,
                password: password,
                salt: challengeResponse.salt!,
                B: challengeResponse.B!,
              );

              if (verbose) {
                print('A: ${_toHex(srp!.A)}');
                print('M: ${_toHex(srp!.M)}');
                print('K: ${_toHex(srp!.K)}');
              }

              // Send AUTH_LOGON_PROOF
              final proofPacket = AuthLogonProofPacket(A: srp!.A, M: srp!.M);
              final proofBytes = proofPacket.toBytes();

              if (verbose) {
                _debugPrintPacket('send', proofBytes);
              }

              socket!.add(proofBytes);
              await socket.flush();
              proofSent = true;

              if (verbose) print('Sent AUTH_LOGON_PROOF');
            }
          }

          // Handle proof response
          if (proofSent && !realmListSent) {
            final proofResponse = AuthLogonProofResponse.parse(buffer);
            if (proofResponse != null) {
              // Consume proof response bytes
              buffer.removeRange(0, 32); // AUTH_LOGON_PROOF response is 32 bytes

              if (!proofResponse.isSuccess) {
                if (!completer.isCompleted) {
                  completer.complete(AuthResult.failure(
                    proofResponse.result,
                    'Authentication failed: ${_errorCodeToString(proofResponse.result)}',
                  ));
                }
                return;
              }

              if (verbose) print('Authentication successful!');

              // Store session key
              sessionKey = srp!.K;

              // If realm list requested, send request
              if (requestRealms) {
                if (verbose) print('Requesting realm list...');

                final realmListPacket = RealmListRequestPacket();
                final realmListBytes = realmListPacket.toBytes();

                if (verbose) {
                  _debugPrintPacket('send', realmListBytes);
                }

                socket!.add(realmListBytes);
                await socket.flush();
                realmListSent = true;

                if (verbose) print('Sent REALM_LIST request');
              } else {
                // No realm list requested, complete with success
                if (!completer.isCompleted) {
                  completer.complete(AuthResult.success(sessionKey!));
                }
              }
            }
          }

          // Handle realm list response
          if (realmListSent) {
            final realmListResponse = RealmListResponse.parse(buffer);
            if (realmListResponse != null) {
              final consumed = RealmListResponse.getConsumedBytes(buffer);
              buffer.removeRange(0, consumed);

              if (verbose) {
                print('Received ${realmListResponse.realms.length} realms:');
                for (final realm in realmListResponse.realms) {
                  print('  - $realm');
                }
              }

              if (!completer.isCompleted) {
                completer.complete(AuthResult.success(
                  sessionKey!,
                  realms: realmListResponse.realms,
                ));
              }
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(AuthResult.failure(-1, 'Socket error: $e'));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(AuthResult.failure(-1, 'Connection closed'));
          }
        },
      );

      // Send AUTH_LOGON_CHALLENGE
      final challengePacket = AuthLogonChallengePacket(username: username);
      final challengeBytes = challengePacket.toBytes();

      // Delay to allow server to initialize
      await Future.delayed(connectionDelay ?? Duration(milliseconds: 100));

      if (verbose) {
        _debugPrintPacket('send', challengeBytes);
      }

      socket.add(challengeBytes);
      await socket.flush();
      challengeSent = true;

      if (verbose) print('Sent AUTH_LOGON_CHALLENGE');

      // Wait for completion (with timeout)
      final result = await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => AuthResult.failure(-1, 'Authentication timeout'),
      );

      return result;
    } catch (e) {
      return AuthResult.failure(-1, 'Connection error: $e');
    } finally {
      await socket?.close();
    }
  }

  /// Request realm list from server
  /// Must be called AFTER successful authentication
  Future<AuthResult> getRealmList({
    Duration? connectionDelay,
    bool verbose = false,
  }) async {
    Socket? socket;

    try {
      // Connect to server
      if (verbose) print('Connecting to $host:$port...');
      socket = await Socket.connect(host, port);
      if (verbose) print('Connected!');

      final completer = Completer<AuthResult>();
      List<int> buffer = [];

      // Listen for server responses
      socket.listen(
        (data) {
          buffer.addAll(data);

          if (verbose) {
            _debugPrintPacket('recv', data);
          }

          // Try to parse realm list response
          final realmListResponse = RealmListResponse.parse(buffer);
          if (realmListResponse != null) {
            if (verbose) {
              print('Received ${realmListResponse.realms.length} realms:');
              for (final realm in realmListResponse.realms) {
                print('  - $realm');
              }
            }

            if (!completer.isCompleted) {
              completer.complete(AuthResult.success(
                Uint8List(0), // No session key for realm list
                realms: realmListResponse.realms,
              ));
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(AuthResult.failure(-1, 'Socket error: $e'));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(AuthResult.failure(-1, 'Connection closed'));
          }
        },
      );

      // Send REALM_LIST request
      final realmListPacket = RealmListRequestPacket();
      final realmListBytes = realmListPacket.toBytes();

      // Delay to allow server to initialize
      await Future.delayed(connectionDelay ?? Duration(milliseconds: 100));

      if (verbose) {
        _debugPrintPacket('send', realmListBytes);
      }

      socket.add(realmListBytes);
      await socket.flush();

      if (verbose) print('Sent REALM_LIST request');

      // Wait for completion (with timeout)
      final result = await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => AuthResult.failure(-1, 'Realm list request timeout'),
      );

      return result;
    } catch (e) {
      return AuthResult.failure(-1, 'Connection error: $e');
    } finally {
      await socket?.close();
    }
  }

  /// Convert bytes to hex string
  String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Debug print packet
  void _debugPrintPacket(String direction, List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('[$direction ${bytes.length} bytes] $hex');
  }

  /// Convert error code to string
  String _errorCodeToString(int code) {
    switch (code) {
      case WOW_SUCCESS:
        return 'Success';
      case WOW_FAIL_UNKNOWN_ACCOUNT:
        return 'Unknown account or incorrect password';
      case WOW_FAIL_INCORRECT_PASSWORD:
        return 'Incorrect password';
      case WOW_FAIL_ALREADY_ONLINE:
        return 'Account already online';
      case WOW_FAIL_NO_TIME:
        return 'No game time remaining';
      case WOW_FAIL_DB_BUSY:
        return 'Database busy, try again later';
      case WOW_FAIL_VERSION_INVALID:
        return 'Invalid client version';
      case WOW_FAIL_VERSION_UPDATE:
        return 'Client version update required';
      case WOW_FAIL_INVALID_SERVER:
        return 'Invalid server';
      case WOW_FAIL_SUSPENDED:
        return 'Account suspended';
      case WOW_FAIL_FAIL_NOACCESS:
        return 'No access to this account';
      case WOW_FAIL_SUCCESS_SURVEY:
        return 'Success with survey';
      case WOW_FAIL_PARENTCONTROL:
        return 'Parental control restrictions';
      case WOW_FAIL_LOCKED_ENFORCED:
        return 'Account locked (security)';
      default:
        return 'Authentication failed (code: $code)';
    }
  }
}
