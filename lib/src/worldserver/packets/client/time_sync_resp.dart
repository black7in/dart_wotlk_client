import 'dart:typed_data';
import '../../opcodes/opcodes.dart';

/// CMSG_TIME_SYNC_RESP packet
///
/// Sent by client in response to SMSG_TIME_SYNC_REQ
class TimeSyncRespPacket {
  final int counter;
  final int ticks;

  TimeSyncRespPacket({
    required this.counter,
    required this.ticks,
  });

  /// Build the client packet
  Uint8List buildClientPacket() {
    // Packet structure:
    // uint32 counter
    // uint32 ticks (client ticks/time)
    final packet = ByteData(14);

    // Size (2 bytes, big endian) - 4 (opcode) + 8 (payload)
    packet.setUint16(0, 12, Endian.big);

    // Opcode (4 bytes, little endian)
    packet.setUint32(2, ClientOpcode.CMSG_TIME_SYNC_RESP.value, Endian.little);

    // Counter (4 bytes, little endian)
    packet.setUint32(6, counter, Endian.little);

    // Ticks (4 bytes, little endian)
    packet.setUint32(10, ticks, Endian.little);

    return packet.buffer.asUint8List();
  }
}
