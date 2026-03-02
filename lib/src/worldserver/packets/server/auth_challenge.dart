/// SMSG_AUTH_CHALLENGE packet
/// 
/// Sent by server immediately after client connects.
/// Contains challenge data needed for authentication.

import 'dart:typed_data';
import '../../opcodes/opcodes.dart';
import '../packet.dart';

/// Server authentication challenge packet
class AuthChallengePacket extends ServerPacket {
  final int challengeNumber;
  final Uint8List authSeed; // 4 bytes
  final Uint8List serverSeed; // 32 bytes

  AuthChallengePacket({
    required this.challengeNumber,
    required this.authSeed,
    required this.serverSeed,
  }) {
    assert(authSeed.length == 4, 'authSeed must be 4 bytes');
    assert(serverSeed.length == 32, 'serverSeed must be 32 bytes');
  }

  @override
  int get opcode => ServerOpcode.SMSG_AUTH_CHALLENGE.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();

    // uint32 - challenge number (1...31)
    bb.addByte(challengeNumber & 0xFF);
    bb.addByte((challengeNumber >> 8) & 0xFF);
    bb.addByte((challengeNumber >> 16) & 0xFF);
    bb.addByte((challengeNumber >> 24) & 0xFF);

    // uint8[4] - auth seed
    bb.add(authSeed);

    // uint8[32] - server seed
    bb.add(serverSeed);

    return bb.toBytes();
  }

  /// Parse AUTH_CHALLENGE from server
  static AuthChallengePacket? parse(List<int> buffer) {
    // Need at least: opcode(2) + size(2) + challengeNumber(4) + authSeed(4) + serverSeed(32) = 44 bytes
    if (buffer.length < 44) return null;

    // Skip header (first 4 bytes: size + opcode)
    int pos = 4;

    // uint32 - challenge number
    final challengeNumber = buffer[pos] |
        (buffer[pos + 1] << 8) |
        (buffer[pos + 2] << 16) |
        (buffer[pos + 3] << 24);
    pos += 4;

    // uint8[4] - auth seed
    final authSeed = Uint8List.fromList(buffer.sublist(pos, pos + 4));
    pos += 4;

    // uint8[32] - server seed
    final serverSeed = Uint8List.fromList(buffer.sublist(pos, pos + 32));

    return AuthChallengePacket(
      challengeNumber: challengeNumber,
      authSeed: authSeed,
      serverSeed: serverSeed,
    );
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
    return 'AuthChallengePacket(challengeNumber: $challengeNumber)';
  }
}
