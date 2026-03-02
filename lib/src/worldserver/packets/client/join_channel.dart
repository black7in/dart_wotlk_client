import 'dart:typed_data';
import '../../opcodes/opcodes.dart';

/// CMSG_JOIN_CHANNEL packet
///
/// Sent by client to join a chat channel.
///
/// Structure (from ChannelHandler.cpp::HandleJoinChannel):
///   uint32  channelId   (0 for custom/named channels)
///   uint8   unknown1
///   uint8   unknown2
///   CString channelName
///   CString password    (empty string if none)
class JoinChannelPacket {
  final String channelName;
  final String password;

  JoinChannelPacket({required this.channelName, this.password = ''});

  Uint8List buildClientPacket() {
    final body = BytesBuilder();

    // channelId (uint32) = 0 for custom channels
    body.add([0x00, 0x00, 0x00, 0x00]);

    // unknown1, unknown2
    body.addByte(0x00);
    body.addByte(0x00);

    // channelName (CString)
    for (final byte in channelName.codeUnits) body.addByte(byte);
    body.addByte(0x00);

    // password (CString)
    for (final byte in password.codeUnits) body.addByte(byte);
    body.addByte(0x00);

    final bodyBytes = body.toBytes();
    final size = 4 + bodyBytes.length; // opcode (4 bytes) + body

    final packet = BytesBuilder();

    // size (2 bytes, big-endian)
    packet.addByte((size >> 8) & 0xFF);
    packet.addByte(size & 0xFF);

    // opcode (4 bytes, little-endian)
    final opcode = ClientOpcode.CMSG_JOIN_CHANNEL.value;
    packet.addByte(opcode & 0xFF);
    packet.addByte((opcode >> 8) & 0xFF);
    packet.addByte((opcode >> 16) & 0xFF);
    packet.addByte((opcode >> 24) & 0xFF);

    packet.add(bodyBytes);
    return packet.toBytes();
  }
}
