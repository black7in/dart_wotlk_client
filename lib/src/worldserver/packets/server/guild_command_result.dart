import 'dart:typed_data';
import 'dart:convert';
import '../packet.dart';
import '../../opcodes/opcodes.dart';

/// SMSG_GUILD_COMMAND_RESULT - Guild command result/error
/// Opcode: 0x093
/// 
/// Sent when a guild command fails or succeeds
/// Packet structure:
/// - int32: command type
/// - String: name (null-terminated)
/// - int32: result/error code
class GuildCommandResultPacket extends ServerPacket {
  late final int command;
  late final String name;
  late final int result;

  GuildCommandResultPacket();

  @override
  int get opcode => ServerOpcode.SMSG_GUILD_COMMAND_RESULT.value;

  @override
  Uint8List toBytes() {
    throw UnimplementedError('GuildCommandResultPacket is receive-only');
  }

  /// Parse the packet data
  void parse(Uint8List data) {
    try {
      var offset = 0;

      // Read command (int32, little-endian)
      if (offset + 4 > data.length) return;
      command = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24);
      offset += 4;

      // Read name (CString)
      final nameBytes = <int>[];
      while (offset < data.length && data[offset] != 0) {
        nameBytes.add(data[offset]);
        offset++;
      }
      name = utf8.decode(nameBytes);
      if (offset < data.length) offset++; // skip null terminator

      // Read result (int32, little-endian)
      if (offset + 4 > data.length) {
        result = 0;
        return;
      }
      result = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24);
    } catch (e) {
      command = 0;
      name = '';
      result = 0;
    }
  }

  /// Get command name
  String get commandName {
    switch (command) {
      case 0: return 'CREATE';
      case 1: return 'INVITE';
      case 3: return 'QUIT';
      case 5: return 'ROSTER';
      case 6: return 'PROMOTE';
      case 7: return 'DEMOTE';
      case 8: return 'REMOVE';
      case 10: return 'CHANGE_LEADER';
      case 11: return 'EDIT_MOTD';
      case 13: return 'GUILD_CHAT';
      case 14: return 'FOUNDER';
      case 16: return 'CHANGE_RANK';
      case 19: return 'PUBLIC_NOTE';
      case 21: return 'VIEW_TAB';
      case 22: return 'MOVE_ITEM';
      case 25: return 'REPAIR';
      default: return 'UNKNOWN($command)';
    }
  }

  /// Get error message in Spanish
  String get errorMessage {
    if (result == 0) return ''; // Success

    // Common errors
    switch (result) {
      case 9: // ERR_GUILD_PLAYER_NOT_IN_GUILD
      case 10: // ERR_GUILD_PLAYER_NOT_IN_GUILD_S
        return 'No estás en una guild';
      case 1: // ERR_GUILD_INTERNAL
        return 'Error interno de guild';
      case 2: // ERR_ALREADY_IN_GUILD
        return 'Ya estás en una guild';
      case 3: // ERR_ALREADY_IN_GUILD_S
        return name.isNotEmpty 
            ? '$name ya está en una guild'
            : 'El jugador ya está en una guild';
      case 4: // ERR_INVITED_TO_GUILD
        return 'Ya has sido invitado a una guild';
      case 5: // ERR_ALREADY_INVITED_TO_GUILD_S
        return name.isNotEmpty
            ? '$name ya ha sido invitado a una guild'
            : 'El jugador ya ha sido invitado a una guild';
      case 6: // ERR_GUILD_NAME_INVALID
        return 'Nombre de guild inválido';
      case 7: // ERR_GUILD_NAME_EXISTS
        return 'Ya existe una guild con ese nombre';
      case 8: // ERR_GUILD_LEADER_LEAVE
        return 'El líder de la guild no puede abandonarla';
      case 11: // ERR_GUILD_PERMISSIONS
        return 'No tienes permisos para hacer eso';
      case 12: // ERR_GUILD_PLAYER_NOT_FOUND
        return name.isNotEmpty
            ? 'No se encontró al jugador $name'
            : 'Jugador no encontrado';
      case 13: // ERR_GUILD_NOT_ALLIED
        return 'Tu guild no está aliada con esa facción';
      case 14: // ERR_GUILD_RANK_TOO_HIGH
        return 'El rango es demasiado alto';
      case 15: // ERR_GUILD_RANK_TOO_LOW
        return 'El rango es demasiado bajo';
      default:
        return 'Error de guild (código: $result)';
    }
  }
}
