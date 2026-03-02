/// SMSG_AUTH_RESPONSE packet
/// 
/// Sent by server in response to CMSG_AUTH_SESSION.
/// Contains authentication result code.

import 'dart:typed_data';
import '../../opcodes/opcodes.dart';
import '../packet.dart';

/// Authentication response codes (from SharedDefines.h)
class AuthResponseCode {
  static const int authOk = 0x0C;
  static const int authFailed = 0x0D;
  static const int authReject = 0x0E;
  static const int authBadServerProof = 0x0F;
  static const int authUnavailable = 0x10;
  static const int authSystemError = 0x11;
  static const int authBillingError = 0x12;
  static const int authBillingExpired = 0x13;
  static const int authVersionMismatch = 0x14;
  static const int authUnknownAccount = 0x15;
  static const int authIncorrectPassword = 0x16;
  static const int authSessionExpired = 0x17;
  static const int authServerShuttingDown = 0x18;
  static const int authAlreadyLoggingIn = 0x19;
  static const int authLoginServerNotFound = 0x1A;
  static const int authWaitQueue = 0x1B;
  static const int authBanned = 0x1C;
  static const int authAlreadyOnline = 0x1D;
  static const int authNoTime = 0x1E;
  static const int authDbBusy = 0x1F;
  static const int authSuspended = 0x20;
  static const int authParentalControl = 0x21;
  static const int authLockedEnforced = 0x22;
  static const int realmListRealmNotFound = 0x27;

  /// Convert response code to human-readable string
  static String codeToString(int code) {
    switch (code) {
      case authOk:
        return 'Authentication successful';
      case authFailed:
        return 'Authentication failed';
      case authReject:
        return 'Authentication rejected';
      case authBadServerProof:
        return 'Bad server proof';
      case authUnavailable:
        return 'Server unavailable';
      case authSystemError:
        return 'System error';
      case authBillingError:
        return 'Billing error';
      case authBillingExpired:
        return 'Billing expired';
      case authVersionMismatch:
        return 'Version mismatch';
      case authUnknownAccount:
        return 'Unknown account';
      case authIncorrectPassword:
        return 'Incorrect password';
      case authSessionExpired:
        return 'Session expired';
      case authServerShuttingDown:
        return 'Server shutting down';
      case authAlreadyLoggingIn:
        return 'Already logging in';
      case authLoginServerNotFound:
        return 'Login server not found';
      case authWaitQueue:
        return 'Wait queue';
      case authBanned:
        return 'Account banned';
      case authAlreadyOnline:
        return 'Already online';
      case authNoTime:
        return 'No game time';
      case authDbBusy:
        return 'Database busy';
      case authSuspended:
        return 'Account suspended';
      case authParentalControl:
        return 'Parental control';
      case authLockedEnforced:
        return 'Account locked';
      case realmListRealmNotFound:
        return 'Realm not found';
      default:
        return 'Unknown error ($code)';
    }
  }
}

/// Server authentication response packet
class AuthResponsePacket extends ServerPacket {
  final int responseCode;

  AuthResponsePacket({
    required this.responseCode,
  });

  bool get isSuccess => responseCode == AuthResponseCode.authOk;

  String get message => AuthResponseCode.codeToString(responseCode);

  @override
  int get opcode => ServerOpcode.SMSG_AUTH_RESPONSE.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();
    bb.addByte(responseCode);
    return bb.toBytes();
  }

  /// Parse AUTH_RESPONSE from server
  static AuthResponsePacket? parse(List<int> buffer) {
    // Need at least: header(4) + responseCode(1) = 5 bytes
    if (buffer.length < 5) return null;

    // Skip header (first 4 bytes: size + opcode)
    final responseCode = buffer[4];

    return AuthResponsePacket(responseCode: responseCode);
  }

  /// Get number of bytes consumed from buffer
  static int getConsumedBytes(List<int> buffer) {
    if (buffer.length < 4) return 0;
    
    // Read size from header (2 bytes, big-endian)
    final size = (buffer[0] << 8) | buffer[1];
    
    // Total consumed = header (4 bytes) + body (size - 2 for opcode)
    return 4 + (size - 2);
  }

  @override
  String toString() {
    return 'AuthResponsePacket(code: 0x${responseCode.toRadixString(16).padLeft(2, '0').toUpperCase()}, message: $message)';
  }
}
