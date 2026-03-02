import 'dart:typed_data';
import 'dart:convert';

/// SMSG_CHANNEL_NOTIFY packet
///
/// Server sends this for all channel events (join, leave, errors, etc.).
///
/// Structure (from Channel.cpp::MakeNotifyPacket):
///   uint8   notifyType  (ChatNotify enum)
///   CString channelName
///   [optional extra fields depending on notifyType]
class ChannelNotifyPacket {
  final int notifyType;
  final String channelName;

  ChannelNotifyPacket({required this.notifyType, required this.channelName});

  // ChatNotify enum values (from Channel.h)
  static const int JOINED_NOTICE          = 0x00; // someone else joined
  static const int LEFT_NOTICE            = 0x01; // someone else left
  static const int YOU_JOINED_NOTICE      = 0x02; // you joined
  static const int YOU_LEFT_NOTICE        = 0x03; // you left
  static const int WRONG_PASSWORD_NOTICE  = 0x04;
  static const int NOT_MEMBER_NOTICE      = 0x05;
  static const int NOT_MODERATOR_NOTICE   = 0x06;
  static const int PASSWORD_CHANGED       = 0x07;
  static const int OWNER_CHANGED          = 0x08;
  static const int PLAYER_NOT_FOUND       = 0x09;
  static const int NOT_OWNER              = 0x0A;
  static const int CHANNEL_OWNER         = 0x0B;
  static const int MODE_CHANGE            = 0x0C;
  static const int ANNOUNCEMENTS_ON       = 0x0D;
  static const int ANNOUNCEMENTS_OFF      = 0x0E;
  static const int MODERATION_ON          = 0x0F;
  static const int MODERATION_OFF         = 0x10;
  static const int MUTED_NOTICE           = 0x11;
  static const int PLAYER_KICKED          = 0x12;
  static const int BANNED_NOTICE          = 0x13;
  static const int PLAYER_BANNED          = 0x14;
  static const int PLAYER_UNBANNED        = 0x15;
  static const int PLAYER_ALREADY_MEMBER  = 0x17;
  static const int INVITE                 = 0x18;
  static const int WRONG_FACTION          = 0x1A;
  static const int INVALID_NAME           = 0x1B;
  static const int THROTTLED              = 0x1F;
  static const int NOT_IN_AREA            = 0x20;
  static const int NOT_IN_LFG             = 0x21;

  static ChannelNotifyPacket? parse(Uint8List data) {
    if (data.length < 2) return null;

    int offset = 0;
    final notifyType = data[offset++];

    // Read channelName (CString)
    int end = offset;
    while (end < data.length && data[end] != 0) end++;
    final channelName = utf8.decode(data.sublist(offset, end), allowMalformed: true);

    return ChannelNotifyPacket(notifyType: notifyType, channelName: channelName);
  }

  /// Human-readable message for this notification
  String get displayMessage {
    switch (notifyType) {
      case YOU_JOINED_NOTICE:     return '[Canal] Te uniste a: $channelName';
      case YOU_LEFT_NOTICE:       return '[Canal] Saliste de: $channelName';
      case WRONG_PASSWORD_NOTICE: return '[Canal] Contraseña incorrecta para: $channelName';
      case NOT_MEMBER_NOTICE:     return '[Canal] No eres miembro de: $channelName';
      case NOT_MODERATOR_NOTICE:  return '[Canal] No eres moderador de: $channelName';
      case MUTED_NOTICE:          return '[Canal] Estás silenciado en: $channelName';
      case BANNED_NOTICE:         return '[Canal] Estás baneado de: $channelName';
      case THROTTLED:             return '[Canal] Mensajes enviados muy rápido en: $channelName';
      case NOT_IN_AREA:           return '[Canal] No estás en el área correcta para: $channelName';
      case NOT_IN_LFG:            return '[Canal] Debes estar en la cola LFG para: $channelName';
      case INVALID_NAME:          return '[Canal] Nombre de canal inválido: $channelName';
      case WRONG_FACTION:         return '[Canal] Facción incorrecta para: $channelName';
      case PLAYER_ALREADY_MEMBER: return '[Canal] El jugador ya es miembro de: $channelName';
      default:                    return '[Canal] Notificación ($notifyType) en: $channelName';
    }
  }

  bool get isError => notifyType != YOU_JOINED_NOTICE &&
      notifyType != YOU_LEFT_NOTICE &&
      notifyType != JOINED_NOTICE &&
      notifyType != LEFT_NOTICE;
}
