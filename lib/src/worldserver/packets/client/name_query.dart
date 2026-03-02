import 'dart:typed_data';
import '../../opcodes/opcodes.dart';
import '../packet.dart';

/// CMSG_NAME_QUERY packet
///
/// Client sends this to request player name information by GUID.
/// The server responds with SMSG_NAME_QUERY_RESPONSE containing:
/// - Player name
/// - Realm name (for cross-realm)
/// - Race, Gender, Class
class NameQueryPacket extends ClientPacket {
  final int guid;

  NameQueryPacket({
    required this.guid,
  });

  @override
  int get opcode => ClientOpcode.CMSG_NAME_QUERY.value;

  @override
  Uint8List toBytes() {
    final body = BytesBuilder();

    // GUID (uint64, little-endian)
    body.add([
      guid & 0xFF,
      (guid >> 8) & 0xFF,
      (guid >> 16) & 0xFF,
      (guid >> 24) & 0xFF,
      (guid >> 32) & 0xFF,
      (guid >> 40) & 0xFF,
      (guid >> 48) & 0xFF,
      (guid >> 56) & 0xFF,
    ]);

    return body.toBytes();
  }
}
