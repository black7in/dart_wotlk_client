import 'dart:typed_data';
import 'dart:convert';

/// A single member entry from SMSG_GUILD_ROSTER
class GuildMemberInfo {
  final int guid;
  final String name;
  final bool online;
  final int rankId;
  final int level;
  final int classId;
  final int gender;
  final int areaId;
  /// Days since last logout (only meaningful when offline)
  final double lastSave;
  final String note;
  final String officerNote;

  GuildMemberInfo({
    required this.guid,
    required this.name,
    required this.online,
    required this.rankId,
    required this.level,
    required this.classId,
    required this.gender,
    required this.areaId,
    required this.lastSave,
    required this.note,
    required this.officerNote,
  });

  String get className {
    const classes = {
      1: 'Warrior', 2: 'Paladin', 3: 'Hunter', 4: 'Rogue',
      5: 'Priest', 6: 'Death Knight', 7: 'Shaman', 8: 'Mage',
      9: 'Warlock', 11: 'Druid',
    };
    return classes[classId] ?? 'Unknown($classId)';
  }

  String get statusString => online ? 'Online' : 'Offline';

  String get lastSeenString {
    if (online) return '';
    if (lastSave < 1) return '< 1 day ago';
    final days = lastSave.floor();
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  @override
  String toString() {
    final status = online ? '[Online] ' : '[Offline] ';
    final seen = online ? '' : ' (${lastSeenString})';
    final noteStr = note.isNotEmpty ? ' - "$note"' : '';
    return '$status$name  Lv.$level $className  Rank:$rankId$seen$noteStr';
  }
}

/// SMSG_GUILD_ROSTER packet (0x08A)
///
/// Sent automatically on login if player is in a guild (via Guild::HandleRoster),
/// or in response to CMSG_GUILD_ROSTER.
///
/// Wire format (GuildPackets.cpp::GuildRoster::Write):
///   uint32  memberCount
///   CString WelcomeText
///   CString InfoText
///   uint32  rankCount
///   for each rank:
///     uint32 Flags
///     uint32 WithdrawGoldLimit
///     for 6 bank tabs:
///       uint32 TabFlags
///       uint32 TabWithdrawItemLimit
///   for each member:
///     uint64  Guid
///     uint8   Status      (0=offline, 1=online)
///     CString Name
///     int32   RankID
///     uint8   Level
///     uint8   ClassID
///     uint8   Gender
///     int32   AreaID
///     [if offline: float LastSave]
///     CString Note
///     CString OfficerNote
class GuildRosterPacket {
  final String welcomeText;
  final String infoText;
  final List<GuildMemberInfo> members;

  GuildRosterPacket({
    required this.welcomeText,
    required this.infoText,
    required this.members,
  });

  static const int _bankMaxTabs = 6;

  static GuildRosterPacket? parse(Uint8List data) {
    if (data.length < 8) return null;

    int offset = 0;

    // memberCount (uint32)
    final memberCount = ByteData.sublistView(data, offset, offset + 4)
        .getUint32(0, Endian.little);
    offset += 4;

    // WelcomeText (CString)
    final welcome = _readCString(data, offset);
    offset += welcome.length + 1;

    // InfoText (CString)
    final info = _readCString(data, offset);
    offset += info.length + 1;

    // rankCount (uint32)
    if (offset + 4 > data.length) return null;
    final rankCount = ByteData.sublistView(data, offset, offset + 4)
        .getUint32(0, Endian.little);
    offset += 4;

    // Skip rank data: each rank = uint32 Flags + uint32 WithdrawGoldLimit
    //                            + 6 × (uint32 TabFlags + uint32 TabWithdrawItemLimit)
    //                          = 8 + 6*8 = 56 bytes
    final rankByteSize = 8 + _bankMaxTabs * 8;
    offset += rankCount * rankByteSize;

    // Member data
    final members = <GuildMemberInfo>[];
    for (int i = 0; i < memberCount; i++) {
      if (offset + 8 > data.length) break;

      // uint64 Guid (little-endian)
      final guid = ByteData.sublistView(data, offset, offset + 8)
          .getInt64(0, Endian.little);
      offset += 8;

      // uint8 Status
      if (offset >= data.length) break;
      final status = data[offset++];
      final online = status != 0;

      // CString Name
      final name = _readCString(data, offset);
      offset += name.length + 1;

      if (offset + 4 > data.length) break;

      // int32 RankID
      final rankId = ByteData.sublistView(data, offset, offset + 4)
          .getInt32(0, Endian.little);
      offset += 4;

      if (offset + 3 > data.length) break;

      // uint8 Level, ClassID, Gender
      final level = data[offset++];
      final classId = data[offset++];
      final gender = data[offset++];

      if (offset + 4 > data.length) break;

      // int32 AreaID
      final areaId = ByteData.sublistView(data, offset, offset + 4)
          .getInt32(0, Endian.little);
      offset += 4;

      // float LastSave (only if offline)
      double lastSave = 0.0;
      if (!online) {
        if (offset + 4 > data.length) break;
        lastSave = ByteData.sublistView(data, offset, offset + 4)
            .getFloat32(0, Endian.little);
        offset += 4;
      }

      // CString Note
      final note = _readCString(data, offset);
      offset += note.length + 1;

      // CString OfficerNote
      final officerNote = _readCString(data, offset);
      offset += officerNote.length + 1;

      members.add(GuildMemberInfo(
        guid: guid,
        name: name,
        online: online,
        rankId: rankId,
        level: level,
        classId: classId,
        gender: gender,
        areaId: areaId,
        lastSave: lastSave,
        note: note,
        officerNote: officerNote,
      ));
    }

    return GuildRosterPacket(
      welcomeText: welcome,
      infoText: info,
      members: members,
    );
  }

  static String _readCString(Uint8List data, int offset) {
    int end = offset;
    while (end < data.length && data[end] != 0) end++;
    return utf8.decode(data.sublist(offset, end), allowMalformed: true);
  }
}
