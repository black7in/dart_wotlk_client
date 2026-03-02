import '../../transport/tcp_transport.dart';
import '../chat_enums.dart';
import '../core/world_client_base.dart';
import '../events/wow_event.dart';
import '../packets/client/join_channel.dart';
import '../packets/client/leave_channel.dart';
import '../packets/client/message_chat.dart';
import '../packets/server/message_chat.dart';
import 'who_mixin.dart';

/// Mixin providing chat message sending, display, and channel management.
mixin ChatMixin on WorldClientBase, WhoMixin {
  /// Send a chat message of the given type.
  Future<void> sendMessage({
    required ChatMsg chatType,
    required String message,
    String? recipient,
    String? channelName,
    Language language = Language.common,
  }) async {
    try {
      MessageChatPacket packet;
      switch (chatType) {
        case ChatMsg.say:
          packet = MessageChatPacket.say(message, language: language);
          break;
        case ChatMsg.yell:
          packet = MessageChatPacket.yell(message, language: language);
          break;
        case ChatMsg.whisper:
          if (recipient == null || recipient.isEmpty) {
            throw ArgumentError('Recipient is required for WHISPER messages');
          }
          packet = MessageChatPacket.whisper(recipient, message, language: language);
          break;
        case ChatMsg.emote:
          packet = MessageChatPacket.emote(message);
          break;
        case ChatMsg.guild:
          packet = MessageChatPacket.guild(message, language: language);
          break;
        case ChatMsg.officer:
          packet = MessageChatPacket.officer(message, language: language);
          break;
        case ChatMsg.channel:
          if (channelName == null || channelName.isEmpty) {
            throw ArgumentError('Channel name is required for CHANNEL messages');
          }
          packet = MessageChatPacket.channel(channelName, message, language: language);
          break;
        default:
          throw UnsupportedError(
              'Chat type ${chatType.displayName} is not supported for sending');
      }

      sendEncrypted(packet.buildClientPacket());
      if (transport is TcpTransport) await (transport as TcpTransport).flush();

      if (verbose) {
        final typeStr = chatType.displayName;
        final targetStr = recipient != null
            ? ' to $recipient'
            : (channelName != null ? ' to [$channelName]' : '');
        print('[WorldClient] Sent $typeStr message$targetStr: "$message"');
      }
    } catch (e) {
      if (verbose) print('[WorldClient] Error sending chat message: $e');
      rethrow;
    }
  }

  /// Join a chat channel.
  ///
  /// The server responds with SMSG_CHANNEL_NOTIFY handled in keepSessionAlive.
  Future<void> joinChannel({
    required String channelName,
    String password = '',
  }) async {
    sendEncrypted(
      JoinChannelPacket(channelName: channelName, password: password)
          .buildClientPacket(),
    );
    if (transport is TcpTransport) await (transport as TcpTransport).flush();
  }

  /// Leave a chat channel.
  ///
  /// The server responds with SMSG_CHANNEL_NOTIFY handled in keepSessionAlive.
  Future<void> leaveChannel({
    required String channelName,
  }) async {
    sendEncrypted(LeaveChannelPacket(channelName: channelName).buildClientPacket());
    if (transport is TcpTransport) await (transport as TcpTransport).flush();
  }

  /// Resolve names, format, and emit a [ChatMessageEvent] for an incoming chat packet.
  Future<void> displayChatMessage(MessageChatReceivedPacket message) async {
    final chatType = message.chatMsgType;
    final text = message.message;
    final channelName = message.channelName;
    final senderGuid = message.senderGuid;
    var senderName = message.senderName;
    var receiverName = message.receiverName;
    final receiverGuid = message.receiverGuid;
    final language = message.languageType;

    // Resolve sender name from cache or via NAME_QUERY
    if (senderName == null || senderName.isEmpty) {
      final cached = getPlayerInfo(senderGuid);
      if (cached != null) {
        senderName = cached.name;
      } else {
        final info = await requestPlayerName(guid: senderGuid);
        if (info != null) senderName = info.name;
      }
    }

    // Resolve receiver name for WHISPER_INFORM
    if ((receiverName == null || receiverName.isEmpty) &&
        receiverGuid != null &&
        receiverGuid != 0) {
      final cached = getPlayerInfo(receiverGuid);
      if (cached != null) {
        receiverName = cached.name;
      } else {
        final info = await requestPlayerName(guid: receiverGuid);
        if (info != null) receiverName = info.name;
      }
    }

    if (verbose) {
      print('[Debug] Message text: "$text", length: ${text.length}');
      print('[Debug] Sender name: ${senderName ?? "null"}, GUID: 0x${senderGuid.toRadixString(16)}');
    }

    final resolvedSenderName = () {
      if (senderName != null && senderName.isNotEmpty) return senderName;
      final cached = getPlayerInfo(senderGuid);
      if (cached != null) return cached.name;
      return 'Unknown Player';
    }();

    emitEvent(ChatMessageEvent(
      type: chatType,
      senderName: resolvedSenderName,
      receiverName: receiverName,
      message: text,
      channelName: channelName,
      language: language,
    ));
  }
}
