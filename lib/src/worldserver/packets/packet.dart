/// Base class for all World Server packets
/// 
/// WoW 3.3.5a packet structure:
/// - Header (client->server): size (2 bytes) + opcode (4 bytes, encrypted after auth)
/// - Header (server->client): size (2 bytes) + opcode (2 bytes, encrypted after auth)
/// - Body: variable length data

import 'dart:typed_data';

/// Base class for all world packets
abstract class WorldPacket {
  /// Get the opcode value for this packet
  int get opcode;
  
  /// Serialize packet to bytes (without header)
  Uint8List toBytes();
  
  /// Build complete packet with header (for sending to server)
  /// Client packets use: size(2) + opcode(4) + data
  Uint8List buildClientPacket() {
    final body = toBytes();
    final size = body.length + 4; // 4 bytes for opcode
    
    final bb = BytesBuilder();
    
    // Size (2 bytes, big-endian)
    bb.addByte((size >> 8) & 0xFF);
    bb.addByte(size & 0xFF);
    
    // Opcode (4 bytes, little-endian)
    bb.addByte(opcode & 0xFF);
    bb.addByte((opcode >> 8) & 0xFF);
    bb.addByte((opcode >> 16) & 0xFF);
    bb.addByte((opcode >> 24) & 0xFF);
    
    // Body
    bb.add(body);
    
    return bb.toBytes();
  }
}

/// Base class for packets sent from client to server
abstract class ClientPacket extends WorldPacket {
  // Client-specific functionality can be added here
}

/// Base class for packets sent from server to client
abstract class ServerPacket extends WorldPacket {
  // Server-specific functionality can be added here
  // Each subclass will implement its own parse method
}

/// Packet header information (after decryption)
class PacketHeader {
  final int size;
  final int opcode;
  
  PacketHeader({
    required this.size,
    required this.opcode,
  });
  
  /// Parse client packet header (size is 2 bytes big-endian, opcode is 4 bytes little-endian)
  static PacketHeader? parseClientHeader(List<int> buffer) {
    if (buffer.length < 6) return null;
    
    final size = (buffer[0] << 8) | buffer[1];
    final opcode = buffer[2] | (buffer[3] << 8) | (buffer[4] << 16) | (buffer[5] << 24);
    
    return PacketHeader(size: size, opcode: opcode);
  }
  
  /// Parse server packet header (size is 2 bytes big-endian, opcode is 2 bytes little-endian)
  static PacketHeader? parseServerHeader(List<int> buffer) {
    if (buffer.length < 4) return null;
    
    final size = (buffer[0] << 8) | buffer[1];
    final opcode = buffer[2] | (buffer[3] << 8);
    
    return PacketHeader(size: size, opcode: opcode);
  }
  
  @override
  String toString() => 'PacketHeader(size: $size, opcode: 0x${opcode.toRadixString(16).padLeft(4, '0').toUpperCase()})';
}
