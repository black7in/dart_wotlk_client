import 'dart:async';

import '../../transport/tcp_transport.dart';
import '../core/world_client_base.dart';
import '../packets/client/guild_roster.dart' as guild_roster_client;
import '../packets/server/guild_roster.dart';

/// Mixin providing guild roster operations.
mixin GuildMixin on WorldClientBase {
  /// Send CMSG_GUILD_ROSTER and wait for the SMSG_GUILD_ROSTER response.
  ///
  /// The response is also stored in [guildMembers] for later access.
  Future<List<GuildMemberInfo>> getGuildRoster({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (pendingGuildRoster != null && !pendingGuildRoster!.isCompleted) {
      return await pendingGuildRoster!.future.timeout(timeout);
    }

    final completer = Completer<List<GuildMemberInfo>>();
    pendingGuildRoster = completer;

    sendEncrypted(guild_roster_client.GuildRosterRequestPacket().buildClientPacket());
    if (transport is TcpTransport) await (transport as TcpTransport).flush();

    try {
      return await completer.future.timeout(timeout);
    } catch (e) {
      pendingGuildRoster = null;
      rethrow;
    }
  }
}
