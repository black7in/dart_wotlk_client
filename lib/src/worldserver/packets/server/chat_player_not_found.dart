import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// SMSG_CHAT_PLAYER_NOT_FOUND - Player not found error
/// Opcode: 0x2A9
/// 
/// Sent when trying to whisper to a player that doesn't exist or is offline
/// Packet structure:
/// - String: player name (null-terminated)
class ChatPlayerNotFoundPacket extends ServerPacket {
  late final String playerName;

  ChatPlayerNotFoundPacket();

  @override
  int get opcode => ServerOpcode.SMSG_CHAT_PLAYER_NOT_FOUND.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('ChatPlayerNotFoundPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    try {
      // Read player name (CString)
      final nameBytes = <int>[];
      var offset = 0;
      
      while (offset < data.length && data[offset] != 0) {
        nameBytes.add(data[offset]);
        offset++;
      }
      
      playerName = utf8.decode(nameBytes);
    } catch (e) {
      playerName = '';
    }
  }
}
