import '../chat_enums.dart';
import '../packets/server/guild_roster.dart';
import '../packets/server/who.dart';

/// Base class for all events emitted by [WorldClient].
sealed class WowEvent {}

/// A chat message received from the server.
class ChatMessageEvent extends WowEvent {
  final ChatMsg? type;
  final String senderName;

  /// Only set for [ChatMsg.whisperInform] (who we whispered to).
  final String? receiverName;
  final String message;

  /// Set for channel messages.
  final String? channelName;
  final Language? language;

  ChatMessageEvent({
    required this.type,
    required this.senderName,
    this.receiverName,
    required this.message,
    this.channelName,
    this.language,
  });
}

/// A guild event notification (join, leave, MOTD, etc.).
class GuildEvent extends WowEvent {
  final String message;
  GuildEvent(this.message);
}

/// A server-broadcast message box (e.g. restart notices).
class ServerMessageEvent extends WowEvent {
  final String messageType;
  final String message;
  ServerMessageEvent({required this.messageType, required this.message});
}

/// The Message of the Day received on login.
class MotdEvent extends WowEvent {
  final List<String> lines;
  MotdEvent(this.lines);
}

/// A channel notification (joined, left, etc.).
class ChannelNotifyEvent extends WowEvent {
  final String message;
  ChannelNotifyEvent(this.message);
}

/// Response to a WHO query.
class WhoResponseEvent extends WowEvent {
  final List<WhoPlayerInfo> players;
  final int totalCount;
  WhoResponseEvent({required this.players, required this.totalCount});
}

/// Guild roster was updated (login or explicit request).
class GuildRosterUpdatedEvent extends WowEvent {
  final List<GuildMemberInfo> members;
  GuildRosterUpdatedEvent(this.members);
}

/// The server closed the connection.
class ConnectionClosedEvent extends WowEvent {}

/// An error occurred on the connection.
class ConnectionErrorEvent extends WowEvent {
  final dynamic error;
  ConnectionErrorEvent(this.error);
}
