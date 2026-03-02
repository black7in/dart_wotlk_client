import 'dart:typed_data';
import '../../opcodes/opcodes.dart';

/// CMSG_READY_FOR_ACCOUNT_DATA_TIMES packet
///
/// Sent by client to indicate readiness to receive account data times
class ReadyForAccountDataTimesPacket {
  /// Build the client packet
  Uint8List buildClientPacket() {
    // This packet has no payload, just header
    final packet = ByteData(6);

    // Size (2 bytes, big endian) - includes opcode (4 bytes)
    packet.setUint16(0, 4, Endian.big);

    // Opcode (4 bytes, little endian)
    packet.setUint32(2, ClientOpcode.CMSG_READY_FOR_ACCOUNT_DATA_TIMES.value, Endian.little);

    return packet.buffer.asUint8List();
  }
}
