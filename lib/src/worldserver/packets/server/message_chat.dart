import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';
import '../../opcodes/opcodes.dart';
import '../../chat_enums.dart';

/// SMSG_MESSAGECHAT - Receive a chat message from server
/// Opcode: 0x096
/// 
/// Packet structure (from Chat.cpp::BuildChatPacket):
/// - uint8: chatType (ChatMsg enum)
/// - int32: language (Language enum)
/// - ObjectGuid: senderGUID (8 bytes)
/// - uint32: flags (usually 0)
/// - [Type-specific fields - varies by chat type]
/// - uint32: message length + 1
/// - String: message (null-terminated)
/// - uint8: chatTag
class MessageChatReceivedPacket extends ServerPacket {
  late final int chatType;
  late final int language;
  late final int senderGuid;
  late final int flags;
  late final String message;
  late final int chatTag;
  String? senderName;
  int? receiverGuid;
  String? receiverName;
  String? channelName;
  int? achievementId;

  MessageChatReceivedPacket();

  @override
  int get opcode => ServerOpcode.SMSG_MESSAGECHAT.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('MessageChatReceivedPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    try {
      var offset = 0;

      // Read chatType (uint8)
      chatType = data[offset];
      offset += 1;

      // Read language (int32, little-endian)
      if (offset + 4 > data.length) return;
      
      language = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24);
      offset += 4;

      // Read senderGUID (uint64, little-endian)
      if (offset + 8 > data.length) return;
      
      senderGuid = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24) |
          (data[offset + 4] << 32) |
          (data[offset + 5] << 40) |
          (data[offset + 6] << 48) |
          (data[offset + 7] << 56);
      offset += 8;

    // Read flags/constant (uint32, little-endian)
    flags = data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
    offset += 4;

    // Type-specific fields
    final msgType = ChatMsg.values.firstWhere(
      (e) => e.value == chatType,
      orElse: () => ChatMsg.say, // fallback
    );

    // Type-specific fields before message (from Chat.cpp::BuildChatPacket switch):
    //
    // DEFAULT case (SAY, YELL, PARTY, RAID, GUILD, OFFICER, EMOTE, TEXTEMOTE,
    //               WHISPER, WHISPER_INFORM, BATTLEGROUND, BATTLEGROUND_LEADER,
    //               CHANNEL, SYSTEM, AFK, DND, IGNORED, ...):
    //   [CHANNEL only]: CString channelName
    //   uint64 receiverGUID
    //
    // MONSTER case (MONSTER_SAY, MONSTER_YELL, MONSTER_EMOTE, RAID_BOSS_*):
    //   uint32 senderNameLen+1
    //   CString senderName
    //   uint64 receiverGUID

    if (msgType == ChatMsg.monsterSay ||
        msgType == ChatMsg.monsterYell ||
        msgType == ChatMsg.monsterEmote) {
      // Read length-prefixed sender name
      if (offset + 4 <= data.length) {
        final nameLength = data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16) |
            (data[offset + 3] << 24);
        offset += 4;
        if (nameLength > 1 && offset + nameLength <= data.length) {
          senderName = utf8.decode(data.sublist(offset, offset + nameLength - 1), allowMalformed: true);
          offset += nameLength;
        }
      }
      // Skip receiverGUID
      offset += 8;
    } else {
      // DEFAULT case — all other types

      // CHANNEL: read channel name CString before receiverGUID
      if (msgType == ChatMsg.channel) {
        int end = offset;
        while (end < data.length && data[end] != 0) end++;
        channelName = utf8.decode(data.sublist(offset, end), allowMalformed: true);
        offset = end + 1; // skip null terminator
      }

      // WHISPER_INFORM: record receiverGUID for display
      if (msgType == ChatMsg.whisperInform && offset + 8 <= data.length) {
        receiverGuid = data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16) |
            (data[offset + 3] << 24) |
            (data[offset + 4] << 32) |
            (data[offset + 5] << 40) |
            (data[offset + 6] << 48) |
            (data[offset + 7] << 56);
      }

      // Skip receiverGUID (always present in default case)
      offset += 8;
    }

    // Receiver GUID handled above in type-specific section

    // Read message length (uint32, little-endian)
    if (offset + 4 > data.length) {
      message = '';
      chatTag = 0;
      return;
    }

    final messageLength = data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
    offset += 4;

    // Read message (CString, but we know the length)
    if (offset + messageLength > data.length) {
      message = '';
      chatTag = 0;
      return;
    }

    final messageBytes = data.sublist(offset, offset + messageLength - 1); // -1 to exclude null terminator
    message = utf8.decode(messageBytes);
    offset += messageLength;

    // Read chatTag (uint8)
    if (offset < data.length) {
      chatTag = data[offset];
      offset += 1;
    } else {
      chatTag = 0;
    }

    // Achievement ID for achievement messages
    if (msgType == ChatMsg.achievement || msgType == ChatMsg.guildAchievement) {
      if (offset + 4 <= data.length) {
        achievementId = data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16) |
            (data[offset + 3] << 24);
      }
    }
    } catch (e, stackTrace) {
      // Error parsing chat message
      if (verbose) {
        print('[MessageChat] Error parsing: $e');
        print('[MessageChat] Stack: $stackTrace');
      }
      rethrow;
    }
  }

  // Enable verbose logging
  static bool verbose = false;

  /// Get chat type as enum
  ChatMsg? get chatMsgType => ChatMsg.values.cast<ChatMsg?>().firstWhere(
        (e) => e?.value == chatType,
        orElse: () => null,
      );

  /// Get language as enum
  Language? get languageType => Language.values.cast<Language?>().firstWhere(
        (e) => e?.value == language,
        orElse: () => null,
      );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[MessageChatReceived] ');
    buffer.write('Type: ${chatMsgType?.displayName ?? 'Unknown(0x${chatType.toRadixString(16)})'}, ');
    buffer.write('Language: ${languageType?.displayName ?? 'Unknown($language)'}, ');
    buffer.write('Sender: 0x${senderGuid.toRadixString(16)}');
    
    if (channelName != null) {
      buffer.write(', Channel: $channelName');
    }
    
    buffer.write(', Message: "$message"');
    
    if (chatTag != 0) {
      buffer.write(', Tag: $chatTag');
    }
    
    return buffer.toString();
  }
}
