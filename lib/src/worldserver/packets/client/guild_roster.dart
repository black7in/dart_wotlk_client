import 'dart:typed_data';
import '../../opcodes/opcodes.dart';

/// CMSG_GUILD_ROSTER packet
///
/// Sent by client to request the guild member list.
/// Server responds with SMSG_GUILD_ROSTER.
///
/// Structure: no body (opcode only)
class GuildRosterRequestPacket {
  Uint8List buildClientPacket() {
    const int size = 4; // opcode only, no body
    final packet = BytesBuilder();

    // size (2 bytes, big-endian)
    packet.addByte((size >> 8) & 0xFF);
    packet.addByte(size & 0xFF);

    // opcode (4 bytes, little-endian)
    final opcode = ClientOpcode.CMSG_GUILD_ROSTER.value;
    packet.addByte(opcode & 0xFF);
    packet.addByte((opcode >> 8) & 0xFF);
    packet.addByte((opcode >> 16) & 0xFF);
    packet.addByte((opcode >> 24) & 0xFF);

    return packet.toBytes();
  }
}
