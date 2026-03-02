/// CMSG_AUTH_SESSION packet
/// 
/// Sent by client to authenticate with the world server after
/// connecting and receiving SMSG_AUTH_CHALLENGE.

import 'dart:typed_data';
import '../../opcodes/opcodes.dart';
import '../packet.dart';

/// Client authentication session packet
class AuthSessionPacket extends ClientPacket {
  final int build;
  final int loginServerID;
  final String accountName;
  final int loginServerType;
  final Uint8List localChallenge; // 4 bytes
  final int regionID;
  final int battlegroupID;
  final int realmID;
  final int dosResponse;
  final Uint8List digest; // 20 bytes (SHA1)
  final Uint8List addonInfo;

  AuthSessionPacket({
    required this.build,
    required this.loginServerID,
    required this.accountName,
    required this.loginServerType,
    required this.localChallenge,
    required this.regionID,
    required this.battlegroupID,
    required this.realmID,
    required this.dosResponse,
    required this.digest,
    required this.addonInfo,
  }) {
    assert(localChallenge.length == 4, 'localChallenge must be 4 bytes');
    assert(digest.length == 20, 'digest must be 20 bytes (SHA1)');
  }

  @override
  int get opcode => ClientOpcode.CMSG_AUTH_SESSION.value;

  @override
  Uint8List toBytes() {
    final bb = BytesBuilder();

    // uint32 - build
    bb.addByte(build & 0xFF);
    bb.addByte((build >> 8) & 0xFF);
    bb.addByte((build >> 16) & 0xFF);
    bb.addByte((build >> 24) & 0xFF);

    // uint32 - loginServerID
    bb.addByte(loginServerID & 0xFF);
    bb.addByte((loginServerID >> 8) & 0xFF);
    bb.addByte((loginServerID >> 16) & 0xFF);
    bb.addByte((loginServerID >> 24) & 0xFF);

    // string - account name (null-terminated)
    bb.add(accountName.codeUnits);
    bb.addByte(0); // null terminator

    // uint32 - loginServerType
    bb.addByte(loginServerType & 0xFF);
    bb.addByte((loginServerType >> 8) & 0xFF);
    bb.addByte((loginServerType >> 16) & 0xFF);
    bb.addByte((loginServerType >> 24) & 0xFF);

    // uint8[4] - localChallenge
    bb.add(localChallenge);

    // uint32 - regionID
    bb.addByte(regionID & 0xFF);
    bb.addByte((regionID >> 8) & 0xFF);
    bb.addByte((regionID >> 16) & 0xFF);
    bb.addByte((regionID >> 24) & 0xFF);

    // uint32 - battlegroupID
    bb.addByte(battlegroupID & 0xFF);
    bb.addByte((battlegroupID >> 8) & 0xFF);
    bb.addByte((battlegroupID >> 16) & 0xFF);
    bb.addByte((battlegroupID >> 24) & 0xFF);

    // uint32 - realmID
    bb.addByte(realmID & 0xFF);
    bb.addByte((realmID >> 8) & 0xFF);
    bb.addByte((realmID >> 16) & 0xFF);
    bb.addByte((realmID >> 24) & 0xFF);

    // uint64 - dosResponse
    bb.addByte(dosResponse & 0xFF);
    bb.addByte((dosResponse >> 8) & 0xFF);
    bb.addByte((dosResponse >> 16) & 0xFF);
    bb.addByte((dosResponse >> 24) & 0xFF);
    bb.addByte((dosResponse >> 32) & 0xFF);
    bb.addByte((dosResponse >> 40) & 0xFF);
    bb.addByte((dosResponse >> 48) & 0xFF);
    bb.addByte((dosResponse >> 56) & 0xFF);

    // uint8[20] - digest (SHA1)
    bb.add(digest);

    // addon info (variable length)
    bb.add(addonInfo);

    return bb.toBytes();
  }

  @override
  String toString() {
    return 'AuthSessionPacket(account: $accountName, build: $build, realmID: $realmID)';
  }
}
