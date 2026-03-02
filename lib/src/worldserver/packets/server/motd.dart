import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';

/// SMSG_MOTD packet (Message of the Day)
/// Opcode: 0x33D
/// 
/// Server sends this when player enters world.
/// Contains welcome message that can be multiple lines.
/// 
/// Packet structure (from MotdMgr.cpp):
/// - uint32: lineCount (number of message lines)
/// - CString[]: lines (array of message lines)
/// 
/// The original message is tokenized by '@' character to create multiple lines.
class MotdPacket extends ServerPacket {
  final List<String> lines;

  MotdPacket({
    required this.lines,
  });

  @override
  int get opcode => 0x33D;

  @override
  Uint8List toBytes() {
    // Not used for server packets (we only parse them)
    return Uint8List(0);
  }

  /// Parse SMSG_MOTD packet
  ///
  /// Wire format (from AzerothCore MotdMgr.cpp + ByteBuffer.h):
  ///   uint32  lineCount
  ///   CString line[0]   (raw bytes + \0)
  ///   CString line[1]
  ///   ...
  ///
  /// ByteBuffer::operator<<(string_view) writes: bytes then a single \0.
  /// There is NO length prefix — always null-terminated.
  static MotdPacket parse(Uint8List data) {
    if (data.length < 4) return MotdPacket(lines: []);

    int offset = 0;

    // Read line count (uint32 little-endian)
    final lineCount = ByteData.sublistView(data, offset, offset + 4)
        .getUint32(0, Endian.little);
    offset += 4;

    final lines = <String>[];

    for (int i = 0; i < lineCount; i++) {
      if (offset >= data.length) break;

      // Find null terminator
      int end = offset;
      while (end < data.length && data[end] != 0) {
        end++;
      }

      final line = utf8.decode(data.sublist(offset, end), allowMalformed: true);
      offset = end + 1; // skip the \0

      if (line.isNotEmpty) {
        lines.add(line);
      }
    }

    return MotdPacket(lines: lines);
  }

  /// Get the full MOTD as a single string
  String get fullMessage => lines.join('\n');

  @override
  String toString() {
    if (lines.isEmpty) {
      return '[MOTD] (empty)';
    } else if (lines.length == 1) {
      return '[MOTD] ${lines[0]}';
    } else {
      return '[MOTD] (${lines.length} lines)\n${lines.map((l) => '  $l').join('\n')}';
    }
  }
}
