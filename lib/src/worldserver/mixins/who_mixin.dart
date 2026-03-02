import 'dart:async';

import '../core/world_client_base.dart';
import '../models/player_info.dart';
import '../packets/client/name_query.dart';
import '../packets/client/who.dart';
import '../packets/server/who.dart';

/// Mixin providing player name lookup and WHO queries.
mixin WhoMixin on WorldClientBase {
  /// Get player name from cache, or null if not cached.
  String? getPlayerName(int guid) => nameCache[guid]?.name;

  /// Get full player info from cache, or null if not cached.
  PlayerInfo? getPlayerInfo(int guid) => nameCache[guid];

  /// Send CMSG_NAME_QUERY and wait for the response.
  ///
  /// Returns [PlayerInfo] when received, or null on timeout/error.
  Future<PlayerInfo?> requestPlayerName({
    required int guid,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    try {
      // Reuse an existing pending request for the same GUID
      if (pendingNameQueries.containsKey(guid)) {
        return await pendingNameQueries[guid]!.future.timeout(timeout);
      }

      final completer = Completer<PlayerInfo>();
      pendingNameQueries[guid] = completer;

      sendEncrypted(NameQueryPacket(guid: guid).buildClientPacket());

      if (verbose) {
        print('[WorldClient] Sent CMSG_NAME_QUERY for GUID: 0x${guid.toRadixString(16)}');
      }

      try {
        return await completer.future.timeout(timeout);
      } on TimeoutException {
        pendingNameQueries.remove(guid);
        if (verbose) {
          print('[WorldClient] NAME_QUERY timeout for GUID: 0x${guid.toRadixString(16)}');
        }
        return null;
      }
    } catch (e) {
      pendingNameQueries.remove(guid);
      if (verbose) print('[WorldClient] Error in NAME_QUERY: $e');
      return null;
    }
  }

  /// Query online players with the WHO command.
  ///
  /// At most one WHO request may be in flight at a time; subsequent calls
  /// wait for the pending one.
  Future<List<WhoPlayerInfo>> who({
    int? minLevel,
    int? maxLevel,
    String? name,
    String? guild,
    int? zoneId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (pendingWhoRequest != null && !pendingWhoRequest!.isCompleted) {
        if (verbose) print('[WorldClient] WHO request already pending, waiting...');
        return await pendingWhoRequest!.future.timeout(timeout);
      }

      final completer = Completer<List<WhoPlayerInfo>>();
      pendingWhoRequest = completer;

      WhoPacket packet;
      if (name != null && name.isNotEmpty) {
        packet = WhoPacket.byName(name);
      } else if (guild != null && guild.isNotEmpty) {
        packet = WhoPacket.byGuild(guild);
      } else if (minLevel != null && maxLevel != null) {
        packet = WhoPacket.byLevel(minLevel, maxLevel);
      } else if (zoneId != null) {
        packet = WhoPacket.byZone(zoneId);
      } else {
        packet = WhoPacket.all();
      }

      sendEncrypted(packet.buildClientPacket());

      if (verbose) {
        final filterStr = name != null
            ? ' (name: $name)'
            : guild != null
                ? ' (guild: $guild)'
                : minLevel != null
                    ? ' (level: $minLevel-$maxLevel)'
                    : zoneId != null
                        ? ' (zone: $zoneId)'
                        : ' (all players)';
        print('[WorldClient] Sent CMSG_WHO$filterStr');
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (verbose) print('[WorldClient] WHO request timeout');
          return <WhoPlayerInfo>[];
        },
      );
    } catch (e) {
      pendingWhoRequest = null;
      if (verbose) print('[WorldClient] Error in WHO: $e');
      rethrow;
    }
  }
}
