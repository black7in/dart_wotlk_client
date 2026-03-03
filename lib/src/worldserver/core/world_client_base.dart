import 'dart:async';
import 'dart:typed_data';

import '../../transport/i_transport.dart';
import '../auth_crypt.dart';
import '../events/wow_event.dart';
import '../opcodes/opcodes.dart';
import '../models/player_info.dart';
import '../packets/server/who.dart';
import '../packets/server/guild_roster.dart';

/// Abstract base for [WorldClient].
///
/// Declares the shared instance state and utility helpers that all mixins
/// can access via `on WorldClientBase`.
abstract class WorldClientBase {
  final ITransport transport;
  final bool verbose;

  /// Header encryption — null until after CMSG_AUTH_SESSION succeeds.
  AuthCrypt? authCrypt;

  /// Broadcast stream of server events for library consumers.
  final StreamController<WowEvent> _eventController =
      StreamController<WowEvent>.broadcast();

  Stream<WowEvent> get events => _eventController.stream;

  /// Emit a structured event to [events].
  void emitEvent(WowEvent e) {
    if (!_eventController.isClosed) _eventController.add(e);
  }

  // ── Shared mixin state ───────────────────────────────────────────────────

  /// Cache of player names (GUID → PlayerInfo).
  final Map<int, PlayerInfo> nameCache = {};

  /// Pending name query completers (GUID → Completer).
  final Map<int, Completer<PlayerInfo>> pendingNameQueries = {};

  /// Pending WHO request.
  Completer<List<WhoPlayerInfo>>? pendingWhoRequest;

  /// Last received guild roster (updated on login and on demand).
  List<GuildMemberInfo>? guildMembers;

  /// Pending guild roster request.
  Completer<List<GuildMemberInfo>>? pendingGuildRoster;

  /// Persistent TCP receive buffer shared between loginToWorld and
  /// keepSessionAlive.  loginToWorld clears it on entry; keepSessionAlive
  /// inherits whatever bytes loginToWorld left so no partial-packet data is
  /// lost during the phase handoff.
  final List<int> rxBuffer = [];

  /// RC4-decoded header fields for the current partial packet, if any.
  /// Non-null when the 4-byte header has been decrypted but the body has not
  /// fully arrived yet.  Shared so the handoff between loginToWorld and
  /// keepSessionAlive never re-decrypts an already-advanced RC4 position.
  int? rxPendingSize;
  int? rxPendingOpcode;

  WorldClientBase({
    required this.transport,
    this.verbose = false,
  });

  // ── Shared utilities ────────────────────────────────────────────────────

  /// Encrypt the 6-byte client header and write the full packet via transport.
  void sendEncrypted(Uint8List packetData) {
    final header = Uint8List.fromList(packetData.sublist(0, 6));
    authCrypt!.encryptSend(header);
    transport.send(Uint8List.fromList([...header, ...packetData.sublist(6)]));
  }

  /// Hex representation of a byte array.
  String toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Human-readable opcode name for a raw server opcode value.
  String getOpcodeName(int opcode) {
    final serverOp = opcode.toServerOpcode();
    if (serverOp != null) {
      return 'SMSG_${serverOp.name.toUpperCase()} (0x${opcode.toRadixString(16).padLeft(4, '0')})';
    }
    return 'UNKNOWN (0x${opcode.toRadixString(16).padLeft(4, '0')})';
  }

  /// Print a raw packet as hex (only meaningful when verbose is true).
  void debugPrintPacket(String direction, List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('[$direction ${bytes.length} bytes] $hex');
  }

  /// Word-wrap [text] to at most [width] characters per line.
  List<String> wrapText(String text, int width) {
    if (text.length <= width) return [text];
    final lines = <String>[];
    var remaining = text;
    while (remaining.length > width) {
      var breakPoint = width;
      final lastSpace = remaining.substring(0, width).lastIndexOf(' ');
      if (lastSpace > 0 && lastSpace > width * 0.6) breakPoint = lastSpace;
      lines.add(remaining.substring(0, breakPoint));
      remaining = remaining.substring(breakPoint).trim();
    }
    if (remaining.isNotEmpty) lines.add(remaining);
    return lines;
  }
}
