/// World of Warcraft 3.3.5a Opcodes
/// 
/// This file contains only the opcodes we actually implement.
/// Full list can be found in: src/server/game/Server/Protocol/Opcodes.h
/// 
/// Note: Opcode names match exactly the names in AzerothCore's Opcodes.h
/// for easier cross-reference and maintenance.

/// Client to Server opcodes (CMSG)
enum ClientOpcode {
  /// Authentication with world server
  CMSG_AUTH_SESSION(0x1ED),
  
  /// Request character list
  CMSG_CHAR_ENUM(0x037),
  
  /// Login with selected character
  CMSG_PLAYER_LOGIN(0x03D),
  
  /// Send chat message
  CMSG_MESSAGECHAT(0x095),
  
  /// Ping to keep connection alive
  CMSG_PING(0x1DC),
  
  /// Zone update
  CMSG_ZONEUPDATE(0x1F4),
  
  /// Ready for account data times
  CMSG_READY_FOR_ACCOUNT_DATA_TIMES(0x4FF),
  
  /// Time sync response
  CMSG_TIME_SYNC_RESP(0x391),
  
  /// Move worldport acknowledge (bidirectional MSG)
  MSG_MOVE_WORLDPORT_ACK(0x0DC),
  
  /// Query player name by GUID
  CMSG_NAME_QUERY(0x050),
  
  /// Query online players with filters
  ///
  /// Structure:
  /// - uint32: minLevel
  /// - uint32: maxLevel
  /// - CString: playerName
  /// - CString: guildName
  /// - uint32: raceMask
  /// - uint32: classMask
  /// - uint32: zonesCount
  /// - uint32[]: zoneIds
  /// - uint32: stringsCount
  /// - CString[]: searchStrings
  CMSG_WHO(0x062),

  /// Join a chat channel
  ///
  /// Structure:
  /// - uint32: channelId  (0 for custom/named channels)
  /// - uint8:  unknown1
  /// - uint8:  unknown2
  /// - CString: channelName
  /// - CString: password  (empty if none)
  CMSG_JOIN_CHANNEL(0x097),

  /// Leave a chat channel
  ///
  /// Structure:
  /// - uint32: unk (always 0)
  /// - CString: channelName
  CMSG_LEAVE_CHANNEL(0x098),

  /// Request guild member list
  ///
  /// Structure: (no body)
  CMSG_GUILD_ROSTER(0x089);

  const ClientOpcode(this.value);
  final int value;
}

/// Server to Client opcodes (SMSG)
enum ServerOpcode {
  /// Authentication challenge from server
  SMSG_AUTH_CHALLENGE(0x1EC),
  
  /// Authentication response
  SMSG_AUTH_RESPONSE(0x1EE),
  
  /// Warden anti-cheat data
  SMSG_WARDEN_DATA(0x2E6),
  
  /// Character list response
  SMSG_CHAR_ENUM(0x03B),
  
  /// Receive chat message
  SMSG_MESSAGECHAT(0x096),
  
  /// Pong response to ping
  SMSG_PONG(0x1DD),
  
  /// Account data times
  SMSG_ACCOUNT_DATA_TIMES(0x209),
  
  /// Update account data
  SMSG_UPDATE_ACCOUNT_DATA(0x20C),
  
  /// Login verification (position in world)
  SMSG_LOGIN_VERIFY_WORLD(0x236),
  
  /// Compressed update object
  SMSG_COMPRESSED_UPDATE_OBJECT(0x1F6),
  
  /// Time sync request (bidirectional opcode 0x390)
  SMSG_TIME_SYNC_REQ(0x390),
  
  /// Name query response
  SMSG_NAME_QUERY_RESPONSE(0x051),
  
  /// Chat error: player not found
  SMSG_CHAT_PLAYER_NOT_FOUND(0x2A9),
  
  /// Chat error: not in party
  SMSG_CHAT_NOT_IN_PARTY(0x299),
  
  /// Chat error: wrong faction
  SMSG_CHAT_WRONG_FACTION(0x2FB),
  
  /// Chat error: restricted
  SMSG_CHAT_RESTRICTED(0x2FD),
  
  /// Chat error: player ambiguous (multiple matches)
  SMSG_CHAT_PLAYER_AMBIGUOUS(0x2FA),
  
  /// Guild member list
  ///
  /// Structure (GuildPackets.cpp::GuildRoster::Write):
  /// - uint32 memberCount
  /// - CString WelcomeText, CString InfoText
  /// - uint32 rankCount, [rankData...]
  /// - for each member: uint64 Guid, uint8 Status, CString Name,
  ///   int32 RankID, uint8 Level/Class/Gender, int32 AreaID,
  ///   [float LastSave if offline], CString Note, CString OfficerNote
  SMSG_GUILD_ROSTER(0x08A),

  /// Guild event notification (MOTD, member joined/left/online/offline, etc.)
  ///
  /// Structure (from GuildPackets.cpp::GuildEvent::Write):
  /// - uint8:  type       (GuildEvents enum)
  /// - uint8:  paramCount
  /// - CString[paramCount]: params
  /// - [for GE_JOINED/GE_LEFT/GE_SIGNED_ON/GE_SIGNED_OFF: uint64 guid]
  ///
  /// Key GuildEvents: GE_MOTD=2, GE_JOINED=3, GE_LEFT=4,
  ///   GE_SIGNED_ON=12, GE_SIGNED_OFF=13
  SMSG_GUILD_EVENT(0x092),

  /// Guild command result (success or error)
  SMSG_GUILD_COMMAND_RESULT(0x093),
  
  /// Response with list of online players
  /// 
  /// Structure:
  /// - uint32: matchCount (placeholder)
  /// - uint32: displayCount (placeholder)
  /// - For each player:
  ///   - CString: name
  ///   - CString: guildName
  ///   - uint32: level
  ///   - uint32: class
  ///   - uint32: race
  ///   - uint8: gender
  ///   - uint32: zoneId
  /// (matchCount and displayCount are updated at positions 0 and 4)
  SMSG_WHO(0x063),
  
  /// Server message broadcast
  /// 
  /// Structure:
  /// - int32: messageId (ServerMessageType enum)
  /// - String: stringParam (message content)
  /// 
  /// MessageTypes:
  /// - 1: SHUTDOWN_TIME (server shutting down)
  /// - 2: RESTART_TIME (server restarting)
  /// - 3: STRING (custom message)
  /// - 4: SHUTDOWN_CANCELLED
  /// - 5: RESTART_CANCELLED
  SMSG_CHAT_SERVER_MESSAGE(0x291),
  
  /// Message of the Day (MOTD)
  ///
  /// Structure:
  /// - uint32: lineCount (number of lines)
  /// - CString[]: lines (array of message lines)
  ///
  /// Lines are separated by '@' character in the original message
  SMSG_MOTD(0x33D),

  /// Channel event notification
  ///
  /// Structure (from Channel.cpp::MakeNotifyPacket):
  /// - uint8:  notifyType  (ChatNotify enum)
  /// - CString: channelName
  /// - [varies by notifyType]:
  ///   YOU_JOINED (0x02): uint8 flags, uint32 channelId, uint32 unk
  ///   YOU_LEFT   (0x03): uint32 channelId, uint8 isConstant
  ///   others: optional guid/name fields
  SMSG_CHANNEL_NOTIFY(0x099);

  const ServerOpcode(this.value);
  final int value;
}

/// Bidirectional opcodes (MSG)
enum BidirectionalOpcode {
  /// Not commonly used in 3.3.5a, but kept for reference
  null_(0x000);

  const BidirectionalOpcode(this.value);
  final int value;
}

/// Helper extension to convert opcode value to enum
extension OpcodeExtension on int {
  /// Try to find client opcode by value
  ClientOpcode? toClientOpcode() {
    try {
      return ClientOpcode.values.firstWhere((op) => op.value == this);
    } catch (_) {
      return null;
    }
  }

  /// Try to find server opcode by value
  ServerOpcode? toServerOpcode() {
    try {
      return ServerOpcode.values.firstWhere((op) => op.value == this);
    } catch (_) {
      return null;
    }
  }
}
