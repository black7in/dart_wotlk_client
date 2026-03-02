import 'dart:typed_data';

/// SMSG_ACCOUNT_DATA_TIMES - Server sends account data timestamps
/// 
/// Opcode: 0x209 (SMSG_ACCOUNT_DATA_TIMES)
/// 
/// Packet Structure (WotLK):
/// - uint32: Unix timestamp (4 bytes, little-endian)
/// - uint8: Unknown flag (1 byte)
/// - uint32: Mask of account data types (4 bytes, little-endian)
/// - For each set bit in mask:
///   - uint32: Unix timestamp for that data type (4 bytes, little-endian)
/// 
/// The mask determines which account data types have timestamps.
/// In WotLK there are 8 account data types (NUM_ACCOUNT_DATA_TYPES).
class AccountDataTimesPacket {
  final int timestamp;
  final int unknownFlag;
  final int mask;
  final List<int> dataTimes;

  AccountDataTimesPacket({
    required this.timestamp,
    required this.unknownFlag,
    required this.mask,
    required this.dataTimes,
  });

  /// Parse from raw packet data (full packet including header)
  static AccountDataTimesPacket parse(Uint8List buffer) {
    if (buffer.length < 13) {
      // Minimum: header(4) + timestamp(4) + flag(1) + mask(4)
      throw Exception('SMSG_ACCOUNT_DATA_TIMES packet too short: ${buffer.length} bytes');
    }

    int offset = 4; // Skip header (2 bytes size + 2 bytes opcode)

    // Read unix timestamp (uint32, little-endian)
    final timestamp = buffer[offset] |
        (buffer[offset + 1] << 8) |
        (buffer[offset + 2] << 16) |
        (buffer[offset + 3] << 24);
    offset += 4;

    // Read unknown flag (uint8)
    final unknownFlag = buffer[offset];
    offset += 1;

    // Read mask (uint32, little-endian)
    final mask = buffer[offset] |
        (buffer[offset + 1] << 8) |
        (buffer[offset + 2] << 16) |
        (buffer[offset + 3] << 24);
    offset += 4;

    // Read data times for each set bit in mask
    final dataTimes = <int>[];
    for (int i = 0; i < 8; i++) {
      if ((mask & (1 << i)) != 0) {
        if (offset + 4 > buffer.length) {
          throw Exception('SMSG_ACCOUNT_DATA_TIMES packet truncated at data time $i');
        }
        
        final dataTime = buffer[offset] |
            (buffer[offset + 1] << 8) |
            (buffer[offset + 2] << 16) |
            (buffer[offset + 3] << 24);
        dataTimes.add(dataTime);
        offset += 4;
      }
    }

    return AccountDataTimesPacket(
      timestamp: timestamp,
      unknownFlag: unknownFlag,
      mask: mask,
      dataTimes: dataTimes,
    );
  }

  /// Get account data type names
  static const List<String> _dataTypeNames = [
    'GLOBAL_CONFIG_CACHE',
    'PER_CHARACTER_CONFIG_CACHE',
    'GLOBAL_BINDINGS_CACHE',
    'PER_CHARACTER_BINDINGS_CACHE',
    'GLOBAL_MACROS_CACHE',
    'PER_CHARACTER_MACROS_CACHE',
    'PER_CHARACTER_LAYOUT_CACHE',
    'PER_CHARACTER_CHAT_CACHE',
  ];

  @override
  String toString() {
    final sb = StringBuffer();
    sb.writeln('AccountDataTimesPacket(');
    sb.writeln('  timestamp: $timestamp');
    sb.writeln('  unknownFlag: $unknownFlag');
    sb.writeln('  mask: 0x${mask.toRadixString(16).padLeft(8, '0').toUpperCase()}');
    
    int dataIndex = 0;
    for (int i = 0; i < 8; i++) {
      if ((mask & (1 << i)) != 0) {
        final typeName = i < _dataTypeNames.length ? _dataTypeNames[i] : 'UNKNOWN_$i';
        sb.writeln('  $typeName: ${dataTimes[dataIndex]}');
        dataIndex++;
      }
    }
    
    sb.write(')');
    return sb.toString();
  }
}
