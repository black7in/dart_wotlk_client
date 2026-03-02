import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// SMSG_CHAT_NOT_IN_PARTY - Not in party error
/// Opcode: 0x299
/// 
/// Sent when trying to use party chat without being in a party
/// Packet structure:
/// - uint32: error code
class ChatNotInPartyPacket extends ServerPacket {
  late final int errorCode;

  ChatNotInPartyPacket();

  @override
  int get opcode => ServerOpcode.SMSG_CHAT_NOT_IN_PARTY.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('ChatNotInPartyPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    try {
      if (data.length >= 4) {
        errorCode = data[0] |
            (data[1] << 8) |
            (data[2] << 16) |
            (data[3] << 24);
      } else {
        errorCode = 0;
      }
    } catch (e) {
      errorCode = 0;
    }
  }

  /// Get error message
  String get errorMessage {
    switch (errorCode) {
      case 2:
      case 51:
        return 'You are not in a group';
      case 3:
      case 39:
      case 40:
        return 'You are not in a raid';
      default:
        return 'Not in party/raid';
    }
  }
}
