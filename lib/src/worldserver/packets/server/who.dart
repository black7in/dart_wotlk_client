import 'dart:typed_data';
import '../packet.dart';

/// Player information from WHO query
class WhoPlayerInfo {
  final String name;
  final String guildName;
  final int level;
  final int classId;
  final int race;
  final int gender;
  final int zoneId;

  WhoPlayerInfo({
    required this.name,
    required this.guildName,
    required this.level,
    required this.classId,
    required this.race,
    required this.gender,
    required this.zoneId,
  });

  @override
  String toString() {
    final guildInfo = guildName.isNotEmpty ? ' <$guildName>' : '';
    final genderStr = _getGenderStr();
    return '$name$guildInfo - Lvl $level $genderStr ${_getRaceName()} ${_getClassName()} (Zone: $zoneId)';
  }

  String _getClassName() {
    const classes = {
      1: 'Warrior',
      2: 'Paladin',
      3: 'Hunter',
      4: 'Rogue',
      5: 'Priest',
      6: 'Death Knight',
      7: 'Shaman',
      8: 'Mage',
      9: 'Warlock',
      11: 'Druid',
    };
    return classes[classId] ?? 'Unknown';
  }

  String _getRaceName() {
    const races = {
      1: 'Human',
      2: 'Orc',
      3: 'Dwarf',
      4: 'Night Elf',
      5: 'Undead',
      6: 'Tauren',
      7: 'Gnome',
      8: 'Troll',
      10: 'Blood Elf',
      11: 'Draenei',
    };
    return races[race] ?? 'Unknown';
  }

  String _getGenderStr() {
    return gender == 0 ? 'Male' : 'Female';
  }
}

/// SMSG_WHO response packet
/// Opcode: 0x063
/// 
/// Packet structure (from MiscHandler.cpp HandleWhoOpcode):
/// - uint32: matchCount (total matches found, placeholder at offset 0)
/// - uint32: displayCount (players displayed, placeholder at offset 4)
/// - For each player displayed:
///   - CString: name
///   - CString: guildName
///   - uint32: level
///   - uint32: class
///   - uint32: race
///   - uint8: gender (added in 3.3.5)
///   - uint32: zoneId
/// - The matchCount and displayCount are written again at positions 0 and 4
class WhoResponsePacket extends ServerPacket {
  final List<WhoPlayerInfo> players;
  final int totalCount;

  WhoResponsePacket({
    required this.players,
    required this.totalCount,
  });

  @override
  int get opcode => 0x063;

  @override
  Uint8List toBytes() {
    // Not used for server packets (we only parse them)
    return Uint8List(0);
  }

  /// Parse SMSG_WHO packet
  static WhoResponsePacket parse(Uint8List data) {
    int offset = 0;

    // Read match count (uint32) - placeholder value
    final matchCount = _readUint32(data, offset);
    offset += 4;

    // Read display count (uint32) - this is the actual count we'll iterate
    final displayCount = _readUint32(data, offset);
    offset += 4;

    final players = <WhoPlayerInfo>[];

    // Read each player
    for (int i = 0; i < displayCount; i++) {
      // Name (CString)
      final nameData = _readCString(data, offset);
      final name = nameData[0];
      offset = nameData[1];

      // Guild name (CString)
      final guildData = _readCString(data, offset);
      final guildName = guildData[0];
      offset = guildData[1];

      // Level (uint32)
      final level = _readUint32(data, offset);
      offset += 4;

      // Class (uint32)
      final classId = _readUint32(data, offset);
      offset += 4;

      // Race (uint32)
      final race = _readUint32(data, offset);
      offset += 4;

      // Gender (uint8) - Added in 3.3.5
      final gender = data[offset];
      offset += 1;

      // Zone ID (uint32)
      final zoneId = _readUint32(data, offset);
      offset += 4;

      players.add(WhoPlayerInfo(
        name: name,
        guildName: guildName,
        level: level,
        classId: classId,
        race: race,
        gender: gender,
        zoneId: zoneId,
      ));
    }

    return WhoResponsePacket(
      players: players,
      totalCount: matchCount,
    );
  }

  static int _readUint32(Uint8List data, int offset) {
    return ByteData.view(data.buffer, data.offsetInBytes + offset, 4)
        .getUint32(0, Endian.little);
  }

  static List<dynamic> _readCString(Uint8List data, int offset) {
    final start = offset;
    while (offset < data.length && data[offset] != 0) {
      offset++;
    }
    final str = String.fromCharCodes(data.sublist(start, offset));
    offset++; // Skip null terminator
    return [str, offset];
  }
}
