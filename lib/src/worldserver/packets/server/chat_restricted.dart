import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// SMSG_CHAT_RESTRICTED - Chat restricted error
/// Opcode: 0x2FD
/// 
/// Sent when player is restricted from chatting
/// Packet structure:
/// - uint8: restriction type
class ChatRestrictedPacket extends ServerPacket {
  late final int restrictionType;

  ChatRestrictedPacket();

  @override
  int get opcode => ServerOpcode.SMSG_CHAT_RESTRICTED.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('ChatRestrictedPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    try {
      if (data.isNotEmpty) {
        restrictionType = data[0];
      } else {
        restrictionType = 0;
      }
    } catch (e) {
      restrictionType = 0;
    }
  }

  /// Get restriction message
  String get restrictionMessage {
    switch (restrictionType) {
      case 0:
        return 'Chat restricted';
      case 1:
        return 'Chat throttled';
      default:
        return 'Chat restricted (type: $restrictionType)';
    }
  }
}
