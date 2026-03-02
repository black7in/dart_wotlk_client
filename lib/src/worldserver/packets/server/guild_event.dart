import 'dart:typed_data';
import 'dart:convert';

/// SMSG_GUILD_EVENT packet (0x092)
///
/// Sent by server for guild events: MOTD, member joined/left/online/offline,
/// rank changes, leader changes, etc.
///
/// Structure (from GuildPackets.cpp::GuildEvent::Write):
///   uint8   type        (GuildEvents enum)
///   uint8   paramCount
///   CString params[paramCount]
///   [for GE_JOINED/GE_LEFT/GE_SIGNED_ON/GE_SIGNED_OFF: uint64 guid]
class GuildEventPacket {
  final int type;
  final List<String> params;
  final int? guid; // only present for join/leave/online/offline events

  GuildEventPacket({required this.type, required this.params, this.guid});

  // GuildEvents enum values (from Guild.h)
  static const int GE_PROMOTION           = 0;
  static const int GE_DEMOTION            = 1;
  static const int GE_MOTD               = 2;
  static const int GE_JOINED             = 3;
  static const int GE_LEFT               = 4;
  static const int GE_REMOVED            = 5;
  static const int GE_LEADER_IS          = 6;
  static const int GE_LEADER_CHANGED     = 7;
  static const int GE_DISBANDED          = 8;
  static const int GE_TABARDCHANGE       = 9;
  static const int GE_RANK_UPDATED       = 10;
  static const int GE_RANK_DELETED       = 11;
  static const int GE_SIGNED_ON          = 12;
  static const int GE_SIGNED_OFF         = 13;

  static GuildEventPacket? parse(Uint8List data) {
    if (data.length < 2) return null;

    int offset = 0;
    final type = data[offset++];
    final paramCount = data[offset++];

    final params = <String>[];
    for (int i = 0; i < paramCount; i++) {
      if (offset >= data.length) break;
      int end = offset;
      while (end < data.length && data[end] != 0) end++;
      params.add(utf8.decode(data.sublist(offset, end), allowMalformed: true));
      offset = end + 1;
    }

    // Read GUID (8 bytes, little-endian) for events that include it
    int? guid;
    if (type == GE_JOINED || type == GE_LEFT ||
        type == GE_SIGNED_ON || type == GE_SIGNED_OFF) {
      if (offset + 8 <= data.length) {
        guid = ByteData.sublistView(data, offset, offset + 8)
            .getInt64(0, Endian.little);
        offset += 8;
      }
    }

    return GuildEventPacket(type: type, params: params, guid: guid);
  }

  /// Human-readable message for this event
  String get displayMessage {
    switch (type) {
      case GE_MOTD:
        final motd = params.isNotEmpty ? params[0] : '';
        return motd.isNotEmpty ? '[Hermandad] MOTD: $motd' : '';
      case GE_JOINED:
        final name = params.isNotEmpty ? params[0] : '?';
        return '[Hermandad] $name se ha unido a la hermandad.';
      case GE_LEFT:
        final name = params.isNotEmpty ? params[0] : '?';
        return '[Hermandad] $name ha abandonado la hermandad.';
      case GE_SIGNED_ON:
        final name = params.isNotEmpty ? params[0] : '?';
        return '[Hermandad] $name se ha conectado.';
      case GE_SIGNED_OFF:
        final name = params.isNotEmpty ? params[0] : '?';
        return '[Hermandad] $name se ha desconectado.';
      case GE_PROMOTION:
        final promoter = params.isNotEmpty ? params[0] : '?';
        final promoted = params.length > 1 ? params[1] : '?';
        final rank = params.length > 2 ? params[2] : '?';
        return '[Hermandad] $promoter ha ascendido a $promoted a $rank.';
      case GE_DEMOTION:
        final promoter = params.isNotEmpty ? params[0] : '?';
        final demoted = params.length > 1 ? params[1] : '?';
        final rank = params.length > 2 ? params[2] : '?';
        return '[Hermandad] $promoter ha degradado a $demoted a $rank.';
      case GE_REMOVED:
        final removed = params.isNotEmpty ? params[0] : '?';
        final kicker = params.length > 1 ? params[1] : '?';
        return '[Hermandad] $removed ha sido expulsado por $kicker.';
      case GE_LEADER_IS:
        final leader = params.isNotEmpty ? params[0] : '?';
        return '[Hermandad] Líder actual: $leader.';
      case GE_LEADER_CHANGED:
        final oldLeader = params.isNotEmpty ? params[0] : '?';
        final newLeader = params.length > 1 ? params[1] : '?';
        return '[Hermandad] $oldLeader ha cedido el liderazgo a $newLeader.';
      case GE_DISBANDED:
        return '[Hermandad] La hermandad ha sido disuelta.';
      case GE_TABARDCHANGE:
        return '[Hermandad] El tabardo ha sido actualizado.';
      default:
        return '[Hermandad] Evento ($type): ${params.join(', ')}';
    }
  }
}
