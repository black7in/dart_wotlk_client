/// High-level World Server client — assembles all protocol mixins into one class.
import '../../src/transport/i_transport.dart';
import 'core/world_client_base.dart';
import 'mixins/auth_mixin.dart';
import 'mixins/chat_mixin.dart';
import 'mixins/guild_mixin.dart';
import 'mixins/login_mixin.dart';
import 'mixins/session_mixin.dart';
import 'mixins/who_mixin.dart';

/// High-level client for WoW 3.3.5a world server communication.
///
/// Covers the full session lifecycle:
/// - SRP6 authentication (via [AuthMixin])
/// - Character selection and world login (via [AuthMixin] + [LoginMixin])
/// - Chat, channels, and emotes (via [ChatMixin])
/// - Player name lookups and WHO (via [WhoMixin])
/// - Guild roster (via [GuildMixin])
/// - Session keepalive and packet dispatch (via [SessionMixin])
///
/// Structured server events are broadcast on [events].
class WorldClient extends WorldClientBase
    with AuthMixin, WhoMixin, GuildMixin, ChatMixin, LoginMixin, SessionMixin {
  WorldClient({
    required ITransport transport,
    bool verbose = false,
  }) : super(transport: transport, verbose: verbose);
}
