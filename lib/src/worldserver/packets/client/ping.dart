import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// CMSG_PING - Client ping to keep connection alive
/// 
/// Opcode: 0x1DC (CMSG_PING)
/// 
/// Packet Structure:
/// - uint32: Ping value (4 bytes, little-endian)
/// - uint32: Latency in ms (4 bytes, little-endian)
/// 
/// Sent periodically to keep the connection alive and measure latency.
/// The server responds with SMSG_PONG echoing the ping value.
class PingPacket extends ClientPacket {
  final int pingValue;
  final int latency;

  PingPacket({
    required this.pingValue,
    this.latency = 0,
  });

  @override
  int get opcode => ClientOpcode.CMSG_PING.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();
    
    // Write ping value (uint32, little-endian)
    bb.addByte(pingValue & 0xFF);
    bb.addByte((pingValue >> 8) & 0xFF);
    bb.addByte((pingValue >> 16) & 0xFF);
    bb.addByte((pingValue >> 24) & 0xFF);
    
    // Write latency (uint32, little-endian)
    bb.addByte(latency & 0xFF);
    bb.addByte((latency >> 8) & 0xFF);
    bb.addByte((latency >> 16) & 0xFF);
    bb.addByte((latency >> 24) & 0xFF);
    
    return bb.toBytes();
  }

  @override
  String toString() {
    return 'PingPacket(pingValue: $pingValue, latency: $latency)';
  }
}
