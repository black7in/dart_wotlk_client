import 'dart:typed_data';

/// SMSG_PONG - Server response to client ping
/// 
/// Opcode: 0x1DD (SMSG_PONG)
/// 
/// Packet Structure:
/// - uint32: Ping value echoed back (4 bytes, little-endian)
/// 
/// This packet echoes back the ping value sent by the client.
class PongPacket {
  final int pingValue;

  PongPacket({
    required this.pingValue,
  });

  /// Parse from raw packet data (full packet including header)
  static PongPacket parse(Uint8List buffer) {
    if (buffer.length < 8) {
      throw Exception('SMSG_PONG packet too short: ${buffer.length} bytes');
    }

    int offset = 4; // Skip header (2 bytes size + 2 bytes opcode)

    // Read ping value (uint32, little-endian)
    final pingValue = buffer[offset] |
        (buffer[offset + 1] << 8) |
        (buffer[offset + 2] << 16) |
        (buffer[offset + 3] << 24);

    return PongPacket(pingValue: pingValue);
  }

  @override
  String toString() {
    return 'PongPacket(pingValue: $pingValue)';
  }
}
