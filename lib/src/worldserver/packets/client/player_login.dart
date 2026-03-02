import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// CMSG_PLAYER_LOGIN - Client requests to enter the world with a character
/// 
/// Opcode: 0x03D (CMSG_PLAYER_LOGIN)
/// 
/// Packet Structure:
/// - uint64: Character GUID (8 bytes, little-endian)
/// 
/// Sent after receiving character list to login with selected character.
/// The server responds with SMSG_LOGIN_VERIFY_WORLD and other initialization packets.
class PlayerLoginPacket extends ClientPacket {
  final int characterGuid;

  PlayerLoginPacket({
    required this.characterGuid,
  });

  @override
  int get opcode => ClientOpcode.CMSG_PLAYER_LOGIN.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();
    
    // Write character GUID (uint64, little-endian)
    bb.addByte(characterGuid & 0xFF);
    bb.addByte((characterGuid >> 8) & 0xFF);
    bb.addByte((characterGuid >> 16) & 0xFF);
    bb.addByte((characterGuid >> 24) & 0xFF);
    bb.addByte((characterGuid >> 32) & 0xFF);
    bb.addByte((characterGuid >> 40) & 0xFF);
    bb.addByte((characterGuid >> 48) & 0xFF);
    bb.addByte((characterGuid >> 56) & 0xFF);
    
    return bb.toBytes();
  }

  @override
  String toString() {
    return 'PlayerLoginPacket(characterGuid: $characterGuid)';
  }
}
