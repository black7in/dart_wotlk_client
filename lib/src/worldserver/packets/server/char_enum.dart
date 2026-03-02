import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// Character data from SMSG_CHAR_ENUM response
class CharacterData {
  final int guid;
  final String name;
  final int race;
  final int classId;
  final int gender;
  final int skin;
  final int face;
  final int hairStyle;
  final int hairColor;
  final int facialStyle;
  final int level;
  final int zone;
  final int map;
  final double x;
  final double y;
  final double z;
  final int guildId;
  final int characterFlags;
  final int customizeFlags;
  final bool firstLogin;
  final int petDisplayId;
  final int petLevel;
  final int petFamily;
  final List<EquipmentItem> equipment;

  CharacterData({
    required this.guid,
    required this.name,
    required this.race,
    required this.classId,
    required this.gender,
    required this.skin,
    required this.face,
    required this.hairStyle,
    required this.hairColor,
    required this.facialStyle,
    required this.level,
    required this.zone,
    required this.map,
    required this.x,
    required this.y,
    required this.z,
    required this.guildId,
    required this.characterFlags,
    required this.customizeFlags,
    required this.firstLogin,
    required this.petDisplayId,
    required this.petLevel,
    required this.petFamily,
    required this.equipment,
  });

  /// Get race name
  String get raceName {
    const races = {
      1: 'Human', 2: 'Orc', 3: 'Dwarf', 4: 'Night Elf',
      5: 'Undead', 6: 'Tauren', 7: 'Gnome', 8: 'Troll',
      10: 'Blood Elf', 11: 'Draenei'
    };
    return races[race] ?? 'Unknown';
  }

  /// Get class name
  String get className {
    const classes = {
      1: 'Warrior', 2: 'Paladin', 3: 'Hunter', 4: 'Rogue',
      5: 'Priest', 6: 'Death Knight', 7: 'Shaman', 8: 'Mage',
      9: 'Warlock', 11: 'Druid'
    };
    return classes[classId] ?? 'Unknown';
  }

  /// Get gender string
  String get genderName {
    return gender == 0 ? 'Male' : 'Female';
  }

  @override
  String toString() {
    return 'CharacterData(guid: $guid, name: "$name", race: $raceName, class: $className, level: $level, zone: $zone)';
  }
}

/// Equipment item information
class EquipmentItem {
  final int displayId;
  final int inventoryType;
  final int enchantAuraId;

  EquipmentItem({
    required this.displayId,
    required this.inventoryType,
    required this.enchantAuraId,
  });

  @override
  String toString() {
    return 'EquipmentItem(displayId: $displayId, type: $inventoryType, enchant: $enchantAuraId)';
  }
}

/// SMSG_CHAR_ENUM response parser
/// 
/// This packet is sent by the server in response to CMSG_CHAR_ENUM.
/// It contains the list of characters on the account for the current realm.
/// 
/// Opcode: 0x03B (SMSG_CHAR_ENUM)
/// 
/// Structure:
/// - uint8: Number of characters
/// For each character:
///   - uint64: Character GUID
///   - string: Character name (null-terminated)
///   - uint8: Race
///   - uint8: Class
///   - uint8: Gender
///   - uint8: Skin
///   - uint8: Face
///   - uint8: Hair style
///   - uint8: Hair color
///   - uint8: Facial style
///   - uint8: Level
///   - uint32: Zone
///   - uint32: Map
///   - float: X position
///   - float: Y position
///   - float: Z position
///   - uint32: Guild ID
///   - uint32: Character flags
///   - uint32: Customize flags
///   - uint8: First login
///   - uint32: Pet display ID
///   - uint32: Pet level
///   - uint32: Pet family
///   - For each equipment slot (23 slots):
///     - uint32: Display ID
///     - uint8: Inventory type
///     - uint32: Enchant aura ID
class CharEnumResponse extends ServerPacket {
  final List<CharacterData> characters;
  int _bytesConsumed = 0;

  CharEnumResponse({required this.characters});

  @override
  int get opcode => ServerOpcode.SMSG_CHAR_ENUM.value;

  @override
  Uint8List toBytes() {
    // This is a server packet, we don't send it
    throw UnsupportedError('CharEnumResponse cannot be converted to bytes');
  }

  /// Parse SMSG_CHAR_ENUM from server
  static CharEnumResponse? parse(Uint8List data) {
    try {
      final buffer = ByteData.sublistView(data);
      int offset = 0;

      // Read number of characters
      final numChars = buffer.getUint8(offset);
      offset += 1;

      final characters = <CharacterData>[];

      for (int i = 0; i < numChars; i++) {
        // Read GUID (uint64, little-endian)
        final guid = buffer.getUint64(offset, Endian.little);
        offset += 8;

        // Read name (null-terminated string)
        final nameBytes = <int>[];
        while (offset < data.length && data[offset] != 0) {
          nameBytes.add(data[offset]);
          offset++;
        }
        offset++; // Skip null terminator
        final name = utf8.decode(nameBytes);

        // Read appearance data
        final race = buffer.getUint8(offset); offset += 1;
        final classId = buffer.getUint8(offset); offset += 1;
        final gender = buffer.getUint8(offset); offset += 1;
        final skin = buffer.getUint8(offset); offset += 1;
        final face = buffer.getUint8(offset); offset += 1;
        final hairStyle = buffer.getUint8(offset); offset += 1;
        final hairColor = buffer.getUint8(offset); offset += 1;
        final facialStyle = buffer.getUint8(offset); offset += 1;

        // Read level and location
        final level = buffer.getUint8(offset); offset += 1;
        final zone = buffer.getUint32(offset, Endian.little); offset += 4;
        final map = buffer.getUint32(offset, Endian.little); offset += 4;
        final x = buffer.getFloat32(offset, Endian.little); offset += 4;
        final y = buffer.getFloat32(offset, Endian.little); offset += 4;
        final z = buffer.getFloat32(offset, Endian.little); offset += 4;

        // Read guild and flags
        final guildId = buffer.getUint32(offset, Endian.little); offset += 4;
        final characterFlags = buffer.getUint32(offset, Endian.little); offset += 4;
        final customizeFlags = buffer.getUint32(offset, Endian.little); offset += 4;
        final firstLogin = buffer.getUint8(offset) != 0; offset += 1;

        // Read pet info
        final petDisplayId = buffer.getUint32(offset, Endian.little); offset += 4;
        final petLevel = buffer.getUint32(offset, Endian.little); offset += 4;
        final petFamily = buffer.getUint32(offset, Endian.little); offset += 4;

        // Read equipment (23 slots: INVENTORY_SLOT_BAG_END)
        final equipment = <EquipmentItem>[];
        for (int slot = 0; slot < 23; slot++) {
          final displayId = buffer.getUint32(offset, Endian.little); offset += 4;
          final inventoryType = buffer.getUint8(offset); offset += 1;
          final enchantAuraId = buffer.getUint32(offset, Endian.little); offset += 4;
          
          equipment.add(EquipmentItem(
            displayId: displayId,
            inventoryType: inventoryType,
            enchantAuraId: enchantAuraId,
          ));
        }

        characters.add(CharacterData(
          guid: guid,
          name: name,
          race: race,
          classId: classId,
          gender: gender,
          skin: skin,
          face: face,
          hairStyle: hairStyle,
          hairColor: hairColor,
          facialStyle: facialStyle,
          level: level,
          zone: zone,
          map: map,
          x: x,
          y: y,
          z: z,
          guildId: guildId,
          characterFlags: characterFlags,
          customizeFlags: customizeFlags,
          firstLogin: firstLogin,
          petDisplayId: petDisplayId,
          petLevel: petLevel,
          petFamily: petFamily,
          equipment: equipment,
        ));
      }

      final response = CharEnumResponse(characters: characters);
      response._bytesConsumed = offset;
      return response;
    } catch (e) {
      print('Error parsing SMSG_CHAR_ENUM: $e');
      return null;
    }
  }

  /// Get number of bytes consumed during parsing
  int getConsumedBytes() => _bytesConsumed;

  @override
  String toString() {
    return 'CharEnumResponse(characters: ${characters.length})';
  }
}
