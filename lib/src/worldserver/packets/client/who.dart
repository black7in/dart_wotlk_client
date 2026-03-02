import 'dart:typed_data';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// CMSG_WHO packet for querying online players
/// 
/// Allows filtering by level, name, guild, race, class, zone, and custom strings.
/// 
/// Protocol structure:
/// - uint32: minLevel (minimum player level, 0 = no minimum)
/// - uint32: maxLevel (maximum player level, 255 = no maximum)
/// - CString: playerName (player name filter, case-insensitive)
/// - CString: guildName (guild name filter, case-insensitive)
/// - uint32: raceMask (bitmask of races, 0xFFFFFFFF = all races)
/// - uint32: classMask (bitmask of classes, 0xFFFFFFFF = all classes)
/// - uint32: zonesCount (number of zone IDs, max 10)
/// - uint32[]: zoneIds (array of zone IDs to filter)
/// - uint32: stringsCount (number of search strings, max 4)
/// - CString[]: searchStrings (additional search terms)
class WhoPacket extends ClientPacket {
  final int minLevel;
  final int maxLevel;
  final String playerName;
  final String guildName;
  final int raceMask;
  final int classMask;
  final List<int> zones;
  final List<String> searchStrings;

  WhoPacket({
    this.minLevel = 0,
    this.maxLevel = 255,
    this.playerName = '',
    this.guildName = '',
    this.raceMask = 0xFFFFFFFF, // All races
    this.classMask = 0xFFFFFFFF, // All classes
    this.zones = const [],
    this.searchStrings = const [],
  });

  /// Factory: Query all online players (no filters)
  factory WhoPacket.all() {
    return WhoPacket();
  }

  /// Factory: Search by player name
  factory WhoPacket.byName(String name) {
    return WhoPacket(playerName: name);
  }

  /// Factory: Search by guild name
  factory WhoPacket.byGuild(String guild) {
    return WhoPacket(guildName: guild);
  }

  /// Factory: Search by level range
  factory WhoPacket.byLevel(int min, int max) {
    return WhoPacket(minLevel: min, maxLevel: max);
  }

  /// Factory: Search by zone ID
  factory WhoPacket.byZone(int zoneId) {
    return WhoPacket(zones: [zoneId]);
  }

  @override
  int get opcode => ClientOpcode.CMSG_WHO.value;

  @override
  Uint8List toBytes() {
    final buffer = BytesBuilder();

    // Min level (uint32)
    buffer.add(_writeUint32(minLevel));

    // Max level (uint32)
    buffer.add(_writeUint32(maxLevel));

    // Player name (CString)
    buffer.add(_writeCString(playerName));

    // Guild name (CString)
    buffer.add(_writeCString(guildName));

    // Race mask (uint32)
    buffer.add(_writeUint32(raceMask));

    // Class mask (uint32)
    buffer.add(_writeUint32(classMask));

    // Zones count (uint32)
    buffer.add(_writeUint32(zones.length));

    // Zone IDs (uint32 array)
    for (final zone in zones) {
      buffer.add(_writeUint32(zone));
    }

    // Strings count (uint32)
    buffer.add(_writeUint32(searchStrings.length));

    // Search strings (CString array)
    for (final str in searchStrings) {
      buffer.add(_writeCString(str));
    }

    return buffer.toBytes();
  }

  Uint8List _writeUint32(int value) {
    final data = ByteData(4);
    data.setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _writeCString(String str) {
    final bytes = str.codeUnits;
    final buffer = Uint8List(bytes.length + 1);
    buffer.setRange(0, bytes.length, bytes);
    buffer[bytes.length] = 0; // Null terminator
    return buffer;
  }
}
