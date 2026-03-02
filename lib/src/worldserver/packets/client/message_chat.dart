import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';
import '../../opcodes/opcodes.dart';
import '../../chat_enums.dart';

/// CMSG_MESSAGECHAT - Send a chat message
/// Opcode: 0x095
/// 
/// Packet structure (from ChatHandler.cpp):
/// - uint32: type (ChatMsg enum)
/// - uint32: language (Language enum)
/// - For different chat types:
///   * SAY, YELL, EMOTE, PARTY, GUILD, RAID, etc: just message (CString)
///   * WHISPER: recipient name (String) + message (CString)
///   * CHANNEL: channel name (String) + message (CString)
class MessageChatPacket extends ClientPacket {
  final ChatMsg chatType;
  final Language language;
  final String message;
  final String? recipient; // For WHISPER type
  final String? channelName; // For CHANNEL type

  MessageChatPacket({
    required this.chatType,
    required this.language,
    required this.message,
    this.recipient,
    this.channelName,
  });

  /// Create a SAY message packet
  factory MessageChatPacket.say(String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.say,
      language: language,
      message: message,
    );
  }

  /// Create a YELL message packet
  factory MessageChatPacket.yell(String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.yell,
      language: language,
      message: message,
    );
  }

  /// Create a WHISPER message packet
  factory MessageChatPacket.whisper(String recipient, String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.whisper,
      language: language,
      message: message,
      recipient: recipient,
    );
  }

  /// Create an EMOTE message packet
  factory MessageChatPacket.emote(String message) {
    return MessageChatPacket(
      chatType: ChatMsg.emote,
      language: Language.universal,
      message: message,
    );
  }

  /// Create a GUILD message packet
  factory MessageChatPacket.guild(String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.guild,
      language: language,
      message: message,
    );
  }

  /// Create an OFFICER message packet (guild officer chat)
  factory MessageChatPacket.officer(String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.officer,
      language: language,
      message: message,
    );
  }

  /// Create a CHANNEL message packet
  factory MessageChatPacket.channel(String channelName, String message, {Language language = Language.common}) {
    return MessageChatPacket(
      chatType: ChatMsg.channel,
      language: language,
      message: message,
      channelName: channelName,
    );
  }

  @override
  int get opcode => ClientOpcode.CMSG_MESSAGECHAT.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();

    // Write type (uint32, little-endian)
    final type = chatType.value;
    bb.addByte(type & 0xFF);
    bb.addByte((type >> 8) & 0xFF);
    bb.addByte((type >> 16) & 0xFF);
    bb.addByte((type >> 24) & 0xFF);

    // Write language (uint32, little-endian)
    final lang = language.value;
    bb.addByte(lang & 0xFF);
    bb.addByte((lang >> 8) & 0xFF);
    bb.addByte((lang >> 16) & 0xFF);
    bb.addByte((lang >> 24) & 0xFF);

    // Write type-specific fields
    switch (chatType) {
      case ChatMsg.whisper:
        if (recipient == null || recipient!.isEmpty) {
          throw ArgumentError('Recipient is required for WHISPER messages');
        }
        // Write recipient name as String (not CString!)
        final recipientBytes = utf8.encode(recipient!);
        bb.add(recipientBytes);
        bb.addByte(0); // null terminator
        
        // Write message as CString
        final messageBytes = utf8.encode(message);
        bb.add(messageBytes);
        bb.addByte(0); // null terminator
        break;

      case ChatMsg.channel:
        if (channelName == null || channelName!.isEmpty) {
          throw ArgumentError('Channel name is required for CHANNEL messages');
        }
        // Write channel name as String
        final channelBytes = utf8.encode(channelName!);
        bb.add(channelBytes);
        bb.addByte(0); // null terminator
        
        // Write message as CString
        final messageBytes = utf8.encode(message);
        bb.add(messageBytes);
        bb.addByte(0); // null terminator
        break;

      case ChatMsg.say:
      case ChatMsg.yell:
      case ChatMsg.emote:
      case ChatMsg.textEmote:
      case ChatMsg.party:
      case ChatMsg.partyLeader:
      case ChatMsg.guild:
      case ChatMsg.officer:
      case ChatMsg.raid:
      case ChatMsg.raidLeader:
      case ChatMsg.raidWarning:
      case ChatMsg.battleground:
      case ChatMsg.battlegroundLeader:
      case ChatMsg.afk:
      case ChatMsg.dnd:
        // Write message as CString
        final messageBytes = utf8.encode(message);
        bb.add(messageBytes);
        bb.addByte(0); // null terminator
        break;

      default:
        throw UnsupportedError('Chat type ${chatType.displayName} is not supported for sending');
    }

    return bb.toBytes();
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[MessageChatPacket] ');
    buffer.write('Type: ${chatType.displayName}, ');
    buffer.write('Language: ${language.displayName}');
    
    if (recipient != null) {
      buffer.write(', To: $recipient');
    }
    if (channelName != null) {
      buffer.write(', Channel: $channelName');
    }
    
    buffer.write(', Message: "$message"');
    return buffer.toString();
  }
}
