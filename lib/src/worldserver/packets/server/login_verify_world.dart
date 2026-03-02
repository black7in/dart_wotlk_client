import 'dart:typed_data';

/// SMSG_LOGIN_VERIFY_WORLD - Server sends world position after login
/// 
/// Opcode: 0x236 (SMSG_LOGIN_VERIFY_WORLD)
/// 
/// Packet Structure:
/// - uint32: Map ID (4 bytes, little-endian)
/// - float: Position X (4 bytes, little-endian)
/// - float: Position Y (4 bytes, little-endian)
/// - float: Position Z (4 bytes, little-endian)
/// - float: Orientation (4 bytes, little-endian)
/// 
/// Total: 20 bytes
/// 
/// This packet is sent after successful login to verify the player's
/// position in the world.
class LoginVerifyWorldPacket {
  final int mapId;
  final double positionX;
  final double positionY;
  final double positionZ;
  final double orientation;

  LoginVerifyWorldPacket({
    required this.mapId,
    required this.positionX,
    required this.positionY,
    required this.positionZ,
    required this.orientation,
  });

  /// Parse from raw packet data (full packet including header)
  static LoginVerifyWorldPacket parse(Uint8List buffer) {
    if (buffer.length < 24) {
      throw Exception('SMSG_LOGIN_VERIFY_WORLD packet too short: ${buffer.length} bytes');
    }

    int offset = 4; // Skip header (2 bytes size + 2 bytes opcode)

    // Read map ID (uint32, little-endian)
    final mapId = buffer[offset] |
        (buffer[offset + 1] << 8) |
        (buffer[offset + 2] << 16) |
        (buffer[offset + 3] << 24);
    offset += 4;

    // Read position X (float, little-endian)
    final posX = _readFloat(buffer, offset);
    offset += 4;

    // Read position Y (float, little-endian)
    final posY = _readFloat(buffer, offset);
    offset += 4;

    // Read position Z (float, little-endian)
    final posZ = _readFloat(buffer, offset);
    offset += 4;

    // Read orientation (float, little-endian)
    final orientation = _readFloat(buffer, offset);

    return LoginVerifyWorldPacket(
      mapId: mapId,
      positionX: posX,
      positionY: posY,
      positionZ: posZ,
      orientation: orientation,
    );
  }

  /// Helper to read a float from buffer (IEEE 754 single precision, little-endian)
  static double _readFloat(Uint8List buffer, int offset) {
    final bytes = Uint8List.fromList([
      buffer[offset],
      buffer[offset + 1],
      buffer[offset + 2],
      buffer[offset + 3],
    ]);
    return ByteData.sublistView(bytes).getFloat32(0, Endian.little);
  }

  /// Get map name (basic mapping)
  String get mapName {
    switch (mapId) {
      case 0:
        return 'Eastern Kingdoms';
      case 1:
        return 'Kalimdor';
      case 530:
        return 'Outland';
      case 571:
        return 'Northrend';
      default:
        return 'Unknown Map ($mapId)';
    }
  }

  @override
  String toString() {
    return 'LoginVerifyWorldPacket(\n'
        '  mapId: $mapId ($mapName)\n'
        '  position: (${positionX.toStringAsFixed(2)}, ${positionY.toStringAsFixed(2)}, ${positionZ.toStringAsFixed(2)})\n'
        '  orientation: ${orientation.toStringAsFixed(2)}\n'
        ')';
  }
}
