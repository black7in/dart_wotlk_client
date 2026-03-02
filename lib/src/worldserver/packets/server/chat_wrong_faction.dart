import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// SMSG_CHAT_WRONG_FACTION - Wrong faction error
/// Opcode: 0x2FB
/// 
/// Sent when trying to chat with a player from the opposing faction
/// Packet structure: empty (no data)
class ChatWrongFactionPacket extends ServerPacket {
  ChatWrongFactionPacket();

  @override
  int get opcode => ServerOpcode.SMSG_CHAT_WRONG_FACTION.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('ChatWrongFactionPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    // No data in this packet
  }
}
