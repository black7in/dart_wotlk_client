import 'dart:typed_data';
import 'dart:convert';

/// Server message types
enum ServerMessageType {
  /// Server is shutting down
  shutdownTime(1),
  
  /// Server is restarting
  restartTime(2),
  
  /// Custom string message
  string(3),
  
  /// Shutdown was cancelled
  shutdownCancelled(4),
  
  /// Restart was cancelled
  restartCancelled(5);

  const ServerMessageType(this.value);
  final int value;

  static ServerMessageType? fromValue(int value) {
    try {
      return ServerMessageType.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }

  String get displayName {
    switch (this) {
      case ServerMessageType.shutdownTime:
        return 'SHUTDOWN';
      case ServerMessageType.restartTime:
        return 'RESTART';
      case ServerMessageType.string:
        return 'SERVER MESSAGE';
      case ServerMessageType.shutdownCancelled:
        return 'SHUTDOWN CANCELLED';
      case ServerMessageType.restartCancelled:
        return 'RESTART CANCELLED';
    }
  }
}

/// SMSG_CHAT_SERVER_MESSAGE packet
/// Opcode: 0x291
/// 
/// Server sends this for important global messages like:
/// - Server shutdown announcements
/// - Server restart notifications
/// - Custom admin messages
/// 
/// Packet structure (from ChatPackets.cpp):
/// - int32: messageId (ServerMessageType enum)
/// - String: stringParam (message content)
class ChatServerMessagePacket {
  final ServerMessageType messageType;
  final String message;

  ChatServerMessagePacket({
    required this.messageType,
    required this.message,
  });

  /// Parse SMSG_CHAT_SERVER_MESSAGE packet
  ///
  /// Wire format (ChatPackets.cpp::ChatServerMessage::Write):
  ///   int32   MessageID
  ///   CString StringParam  (bytes + \0, via ByteBuffer::operator<<(string))
  static ChatServerMessagePacket parse(Uint8List data) {
    if (data.length < 4) {
      return ChatServerMessagePacket(messageType: ServerMessageType.string, message: '');
    }

    int offset = 0;

    // Read message ID (int32, little-endian)
    final messageId = ByteData.sublistView(data, offset, offset + 4)
        .getInt32(0, Endian.little);
    offset += 4;

    // Read StringParam as CString (null-terminated)
    int end = offset;
    while (end < data.length && data[end] != 0) end++;
    final message = utf8.decode(data.sublist(offset, end), allowMalformed: true);

    final messageType = ServerMessageType.fromValue(messageId) ?? ServerMessageType.string;

    return ChatServerMessagePacket(messageType: messageType, message: message);
  }

  @override
  String toString() {
    return '[${messageType.displayName}] $message';
  }
}
