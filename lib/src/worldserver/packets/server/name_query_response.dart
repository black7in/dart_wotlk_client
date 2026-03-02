import 'dart:convert';
import 'dart:typed_data';
import '../../opcodes/opcodes.dart';
import '../packet.dart';

/// SMSG_NAME_QUERY_RESPONSE packet
/// 
/// Server sends this in response to CMSG_NAME_QUERY.
/// Contains player name, race, class, gender information.
/// 
/// Format (WoW 3.3.5a):
/// - GUID (packed/uint64)
/// - NameUnknown (uint8) - 0 = found, 1 = not found
/// If found:
///   - Name (CString)
///   - RealmName (CString) - empty for same realm
///   - Race (uint8)
///   - Gender (uint8)
///   - Class (uint8)
///   - Declined (uint8) - 0 = no declined names
class NameQueryResponsePacket extends ServerPacket {
  late int guid;
  late bool nameUnknown;
  String? name;
  String? realmName;
  int? race;
  int? gender;
  int? classId;
  
  @override
  int get opcode => ServerOpcode.SMSG_NAME_QUERY_RESPONSE.value;

  @override
  Uint8List toBytes() {
    // Not used for server packets (we only parse them)
    return Uint8List(0);
  }

  /// Parse packet data
  void parse(Uint8List data) {
    var offset = 0;

    // Read PackedGuid (not a plain uint64!)
    // Format: first byte is a mask indicating which bytes are present
    final guidMask = data[offset];
    offset++;
    
    guid = 0;
    for (int i = 0; i < 8; i++) {
      if ((guidMask & (1 << i)) != 0) {
        guid |= (data[offset] << (i * 8));
        offset++;
      }
    }

    // Read NameUnknown flag (uint8)
    nameUnknown = data[offset] != 0;
    offset += 1;

    if (nameUnknown) {
      // Player not found
      return;
    }

    // Read Name (CString)
    final nameBytes = <int>[];
    while (offset < data.length && data[offset] != 0) {
      nameBytes.add(data[offset]);
      offset++;
    }
    name = utf8.decode(nameBytes);
    offset++; // skip null terminator

    // Read RealmName (CString)
    final realmBytes = <int>[];
    while (offset < data.length && data[offset] != 0) {
      realmBytes.add(data[offset]);
      offset++;
    }
    realmName = utf8.decode(realmBytes);
    offset++; // skip null terminator

    // Read Race (uint8)
    if (offset < data.length) {
      race = data[offset];
      offset++;
    }

    // Read Gender (uint8)
    if (offset < data.length) {
      gender = data[offset];
      offset++;
    }

    // Read Class (uint8)
    if (offset < data.length) {
      classId = data[offset];
      offset++;
    }

    // We ignore Declined flag and declined names for now
  }
}
