/// WoW authentication protocol packet definitions
import 'dart:convert';
import 'dart:typed_data';
import '../constants.dart';

/// Base class for authentication packets
abstract class AuthPacket {
  /// Serialize the packet to bytes
  Uint8List toBytes();
}

/// AUTH_LOGON_CHALLENGE packet sent by client
class AuthLogonChallengePacket extends AuthPacket {
  final String username;
  final int build;
  final String platform;
  final String os;
  final String locale;

  AuthLogonChallengePacket({
    required this.username,
    this.build = WOW_BUILD,
    this.platform = PLATFORM,
    this.os = OS_REVERSED,
    this.locale = LOCALE_REVERSED,
  });

  @override
  Uint8List toBytes() {
    final userBytes = utf8.encode(username);
    final I_len = userBytes.length;
    final int size = I_len + 30;

    final bb = BytesBuilder();

    // Command
    bb.addByte(AUTH_LOGON_CHALLENGE);

    // Error (always 0x00 for client->server)
    bb.addByte(0x00);

    // Size (uint16 little-endian)
    bb.addByte(size & 0xff);
    bb.addByte((size >> 8) & 0xff);

    // Game name[4] -> "WoW\0"
    bb.add(ascii.encode('WoW\u0000'));

    // Version (3 bytes)
    bb.addByte(VERSION_MAJOR);
    bb.addByte(VERSION_MINOR);
    bb.addByte(VERSION_PATCH);

    // Build (uint16 little-endian)
    bb.addByte(build & 0xff);
    bb.addByte((build >> 8) & 0xff);

    // Platform[4] -> "x86\0"
    bb.add(ascii.encode('$platform\u0000'));

    // OS[4] -> "niW\0" (reversed)
    bb.add(ascii.encode('$os\u0000'));

    // Locale[4] -> "SUne" (reversed)
    bb.add(ascii.encode(locale));

    // Timezone bias (uint32 little-endian)
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);

    // IP (uint32 little-endian) -> 0
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);

    // Username length and bytes
    bb.addByte(I_len);
    bb.add(userBytes);

    return bb.toBytes();
  }
}

/// Response from server to AUTH_LOGON_CHALLENGE
class AuthLogonChallengeResponse {
  final int result;
  final Uint8List? B;
  final Uint8List? salt;
  final int? securityFlags;

  AuthLogonChallengeResponse({
    required this.result,
    this.B,
    this.salt,
    this.securityFlags,
  });

  bool get isSuccess => result == WOW_SUCCESS;

  /// Parse AUTH_LOGON_CHALLENGE response from server
  static AuthLogonChallengeResponse? parse(List<int> buffer) {
    if (buffer.length < 3) return null;

    final cmd = buffer[0];
    if (cmd != AUTH_LOGON_CHALLENGE) return null;

    final result = buffer[2];

    // If not success, return early
    if (result != WOW_SUCCESS) {
      return AuthLogonChallengeResponse(result: result);
    }

    // Parse success response
    final expectedMin = 3 + 32 + 1 + 1 + 32 + SALT_LENGTH + 16 + 1;
    if (buffer.length < expectedMin) return null;

    int pos = 3;

    // B (32 bytes)
    final B = Uint8List.fromList(buffer.sublist(pos, pos + 32));
    pos += 32;

    // g_len (1 byte)
    final g_len = buffer[pos];
    pos += 1;
    pos += g_len; // skip g bytes

    // N_len (1 byte)
    final N_len = buffer[pos];
    pos += 1;
    pos += N_len; // skip N bytes

    // salt (32 bytes)
    final salt = Uint8List.fromList(buffer.sublist(pos, pos + SALT_LENGTH));
    pos += SALT_LENGTH;

    // versionChallenge (16 bytes)
    pos += 16;

    // securityFlags (1 byte)
    final securityFlags = buffer[pos];

    return AuthLogonChallengeResponse(
      result: result,
      B: B,
      salt: salt,
      securityFlags: securityFlags,
    );
  }

  /// Get the number of bytes consumed from buffer
  static int getConsumedBytes(List<int> buffer) {
    if (buffer.length < 3) return 0;
    final result = buffer[2];
    if (result != WOW_SUCCESS) return 3;

    int pos = 3;
    if (buffer.length <= pos + 32) return 0;
    pos += 32; // B

    if (buffer.length <= pos) return 0;
    final g_len = buffer[pos];
    pos += 1 + g_len;

    if (buffer.length <= pos) return 0;
    final N_len = buffer[pos];
    pos += 1 + N_len;

    pos += SALT_LENGTH; // salt
    pos += 16; // versionChallenge
    pos += 1; // securityFlags

    return pos;
  }
}

/// AUTH_LOGON_PROOF packet sent by client
class AuthLogonProofPacket extends AuthPacket {
  final Uint8List A;
  final Uint8List M;
  final Uint8List crcHash;
  final int numberOfKeys;
  final int securityFlags;

  AuthLogonProofPacket({
    required this.A,
    required this.M,
    Uint8List? crcHash,
    this.numberOfKeys = 0x00,
    this.securityFlags = 0x00,
  }) : crcHash = crcHash ?? Uint8List(20);

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();

    bb.addByte(AUTH_LOGON_PROOF);
    bb.add(A); // 32 bytes
    bb.add(M); // 20 bytes
    bb.add(crcHash); // 20 bytes
    bb.addByte(numberOfKeys);
    bb.addByte(securityFlags);

    return bb.toBytes();
  }
}

/// Response from server to AUTH_LOGON_PROOF
class AuthLogonProofResponse {
  final int result;
  final Uint8List? serverProof;

  AuthLogonProofResponse({
    required this.result,
    this.serverProof,
  });

  bool get isSuccess => result == WOW_SUCCESS;

  /// Parse AUTH_LOGON_PROOF response from server
  static AuthLogonProofResponse? parse(List<int> buffer) {
    if (buffer.length < 2) return null;

    final cmd = buffer[0];
    if (cmd != AUTH_LOGON_PROOF) return null;

    final result = buffer[1];

    if (result != WOW_SUCCESS) {
      return AuthLogonProofResponse(result: result);
    }

    // Success response includes server proof (20 bytes)
    if (buffer.length < 32) return null;

    final serverProof = Uint8List.fromList(buffer.sublist(2, 22));

    return AuthLogonProofResponse(
      result: result,
      serverProof: serverProof,
    );
  }
}

/// REALM_LIST request packet sent by client
class RealmListRequestPacket extends AuthPacket {
  RealmListRequestPacket();

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();

    bb.addByte(REALM_LIST);
    // uint32 - always 0
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);
    bb.addByte(0);

    return bb.toBytes();
  }
}

/// Realm flags
class RealmFlags {
  static const int NONE = 0x00;
  static const int INVALID = 0x01;
  static const int OFFLINE = 0x02;
  static const int SPECIFYBUILD = 0x04;
  static const int UNK1 = 0x08;
  static const int UNK2 = 0x10;
  static const int RECOMMENDED = 0x20;
  static const int NEW = 0x40;
  static const int FULL = 0x80;
}

/// Realm type
class RealmType {
  static const int NORMAL = 0;
  static const int PVP = 1;
  static const int NORMAL2 = 4;
  static const int RP = 6;
  static const int RPPVP = 8;
}

/// Realm information
class RealmInfo {
  final int type;
  final int flags;
  final String name;
  final String address;
  final double population;
  final int characterCount;
  final int timezone;
  final int id;

  // Optional build info (if SPECIFYBUILD flag is set)
  final int? majorVersion;
  final int? minorVersion;
  final int? bugfixVersion;
  final int? build;

  RealmInfo({
    required this.type,
    required this.flags,
    required this.name,
    required this.address,
    required this.population,
    required this.characterCount,
    required this.timezone,
    required this.id,
    this.majorVersion,
    this.minorVersion,
    this.bugfixVersion,
    this.build,
  });

  bool get isOnline => (flags & RealmFlags.OFFLINE) == 0;
  bool get isRecommended => (flags & RealmFlags.RECOMMENDED) != 0;
  bool get isNew => (flags & RealmFlags.NEW) != 0;
  bool get isFull => (flags & RealmFlags.FULL) != 0;

  String get typeString {
    switch (type) {
      case RealmType.NORMAL:
      case RealmType.NORMAL2:
        return 'Normal';
      case RealmType.PVP:
        return 'PvP';
      case RealmType.RP:
        return 'RP';
      case RealmType.RPPVP:
        return 'RP-PvP';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    final status = isOnline ? 'Online' : 'Offline';
    return '$name [$typeString] - $address ($status) - $characterCount chars - Pop: ${(population * 100).toStringAsFixed(0)}%';
  }
}

/// Response from server to REALM_LIST request
class RealmListResponse {
  final List<RealmInfo> realms;

  RealmListResponse({required this.realms});

  /// Parse REALM_LIST response from server
  static RealmListResponse? parse(List<int> buffer) {
    if (buffer.length < 8) return null;

    final cmd = buffer[0];
    if (cmd != REALM_LIST) return null;

    // uint16 - packet size
    final size = buffer[1] | (buffer[2] << 8);

    if (buffer.length < size + 3) return null;

    int pos = 3;

    // uint32 - unknown (always 0)
    pos += 4;

    // uint16 - number of realms (WotLK 3.x)
    final numRealms = buffer[pos] | (buffer[pos + 1] << 8);
    pos += 2;

    final realms = <RealmInfo>[];

    for (int i = 0; i < numRealms; i++) {
      if (pos >= buffer.length) break;

      // uint8 - realm type
      final type = buffer[pos++];

      // uint8 - lock (WotLK 3.x only) - not used by client
      pos++; // skip lock flag

      // uint8 - flags
      final flags = buffer[pos++];

      // string - realm name (null-terminated)
      final nameBytes = <int>[];
      while (pos < buffer.length && buffer[pos] != 0) {
        nameBytes.add(buffer[pos++]);
      }
      pos++; // skip null terminator
      final name = String.fromCharCodes(nameBytes);

      // string - address (null-terminated)
      final addressBytes = <int>[];
      while (pos < buffer.length && buffer[pos] != 0) {
        addressBytes.add(buffer[pos++]);
      }
      pos++; // skip null terminator
      final address = String.fromCharCodes(addressBytes);

      // float - population
      final popBytes = buffer.sublist(pos, pos + 4);
      final population = ByteData.sublistView(Uint8List.fromList(popBytes)).getFloat32(0, Endian.little);
      pos += 4;

      // uint8 - character count
      final characterCount = buffer[pos++];

      // uint8 - timezone
      final timezone = buffer[pos++];

      // uint8 - realm id (WotLK 3.x)
      final id = buffer[pos++];

      // Optional build info (if SPECIFYBUILD flag is set)
      int? majorVersion, minorVersion, bugfixVersion, build;
      if ((flags & RealmFlags.SPECIFYBUILD) != 0) {
        if (pos + 5 <= buffer.length) {
          majorVersion = buffer[pos++];
          minorVersion = buffer[pos++];
          bugfixVersion = buffer[pos++];
          build = buffer[pos] | (buffer[pos + 1] << 8);
          pos += 2;
        }
      }

      realms.add(RealmInfo(
        type: type,
        flags: flags,
        name: name,
        address: address,
        population: population,
        characterCount: characterCount,
        timezone: timezone,
        id: id,
        majorVersion: majorVersion,
        minorVersion: minorVersion,
        bugfixVersion: bugfixVersion,
        build: build,
      ));
    }

    return RealmListResponse(realms: realms);
  }

  /// Get the number of bytes consumed from buffer
  static int getConsumedBytes(List<int> buffer) {
    if (buffer.length < 3) return 0;
    final size = buffer[1] | (buffer[2] << 8);
    return 3 + size;
  }
}
