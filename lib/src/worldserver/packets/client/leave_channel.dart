import 'dart:typed_data';
import '../../opcodes/opcodes.dart';

/// CMSG_LEAVE_CHANNEL packet
///
/// Sent by client to leave a chat channel.
///
/// Structure (from ChannelHandler.cpp::HandleLeaveChannel):
///   uint32  unk         (always 0)
///   CString channelName
class LeaveChannelPacket {
  final String channelName;

  LeaveChannelPacket({required this.channelName});

  Uint8List buildClientPacket() {
    final body = BytesBuilder();

    // unk (uint32) = 0
    body.add([0x00, 0x00, 0x00, 0x00]);

    // channelName (CString)
    for (final byte in channelName.codeUnits) body.addByte(byte);
    body.addByte(0x00);

    final bodyBytes = body.toBytes();
    final size = 4 + bodyBytes.length;

    final packet = BytesBuilder();

    // size (2 bytes, big-endian)
    packet.addByte((size >> 8) & 0xFF);
    packet.addByte(size & 0xFF);

    // opcode (4 bytes, little-endian)
    final opcode = ClientOpcode.CMSG_LEAVE_CHANNEL.value;
    packet.addByte(opcode & 0xFF);
    packet.addByte((opcode >> 8) & 0xFF);
    packet.addByte((opcode >> 16) & 0xFF);
    packet.addByte((opcode >> 24) & 0xFF);

    packet.add(bodyBytes);
    return packet.toBytes();
  }
}
