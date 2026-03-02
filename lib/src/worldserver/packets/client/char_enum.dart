import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// CMSG_CHAR_ENUM packet - Request character list
/// 
/// This packet is sent by the client after successful authentication
/// to request the list of characters on the account for this realm.
/// 
/// Opcode: 0x037 (CMSG_CHAR_ENUM)
/// Payload: Empty (no data)
/// 
/// The server responds with SMSG_CHAR_ENUM containing the character list.
class CharEnumPacket extends ClientPacket {
  @override
  int get opcode => ClientOpcode.CMSG_CHAR_ENUM.value;

  @override
  Uint8List toBytes() {
    // This packet has no payload, just the opcode
    return Uint8List(0);
  }

  @override
  String toString() {
    return 'CharEnumPacket()';
  }
}

