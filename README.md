# dart_wotlk_client

Pure Dart client library for World of Warcraft 3.3.5a (Wrath of the Lich King) servers, targeting [AzerothCore](https://www.azerothcore.org/).

Designed for **headless applications** (bots, monitors, tools, Flutter apps) focused on chat and social features. No graphics, no movement — pure protocol communication.

- No native bindings — runs on Dart VM, Flutter mobile, and (with a WebSocket proxy) Flutter web
- Platform-agnostic transport layer (`ITransport`) — swap `TcpTransport` for any backend
- Structured event stream (`Stream<WowEvent>`) instead of raw print output

---

## Quick Start (CLI)

```bash
dart run bin/auth_client.dart <host> <port> <username> <password> [-v]
```

```bash
# Example
dart run bin/auth_client.dart logon.my-server.com 3724 myaccount mypassword
```

Once in-world:

| Command | Description |
|---------|-------------|
| `/say <msg>` | Say to nearby players |
| `/yell <msg>` | Yell to zone |
| `/w <player> <msg>` | Whisper |
| `/guild <msg>` | Guild chat |
| `/officer <msg>` | Officer chat |
| `/emote <msg>` | Emote |
| `/who [name]` | List online players |
| `/join <channel> [pass]` | Join a chat channel |
| `/leave <channel>` | Leave a channel |
| `/ch <channel> <msg>` | Send to channel |
| `/groster` | Guild member list |
| `/quit` | Disconnect |

---

## Usage as a library

```dart
import 'package:dart_wotlk_client/authserver.dart';
import 'package:dart_wotlk_client/worldserver.dart';

// 1. Authenticate against the auth server (port 3724, SRP6)
final auth = WowAuthClient(host: '127.0.0.1', port: 3724);
final authResult = await auth.authenticate(
  username: 'myuser',
  password: 'mypass',
  requestRealms: true,
);
if (!authResult.success) throw Exception(authResult.message);

final realm = authResult.realms!.first;
final addressParts = realm.address.split(':');

// 2. Create world client with a TCP transport
final worldClient = WorldClient(
  transport: TcpTransport(host: addressParts[0], port: int.parse(addressParts[1])),
  verbose: false,
);

// 3. Listen to structured events
worldClient.events.listen((event) {
  switch (event) {
    case ChatMessageEvent e:
      print('[${e.type?.displayName}] ${e.senderName}: ${e.message}');
    case MotdEvent e:
      print('MOTD: ${e.lines.join('\n')}');
    case GuildEvent e:
      print(e.message);
    case ServerMessageEvent e:
      print('[${e.messageType}] ${e.message}');
    case ChannelNotifyEvent e:
      print(e.message);
    case ConnectionClosedEvent _:
      print('Disconnected.');
    default:
      break;
  }
});

// 4. Authenticate + get character list (single round-trip)
final connResult = await worldClient.authenticateAndGetCharacters(
  accountName: 'myuser',
  sessionKey: authResult.sessionKey!,
  realmId: realm.id,
);
if (!connResult.success) throw Exception(connResult.message);

// 5. Enter world with first character
final loginResult = await worldClient.loginToWorld(
  characterGuid: connResult.characters!.first.guid,
);
if (!loginResult.success) throw Exception(loginResult.message);

// 6. Send messages
await worldClient.sendMessage(chatType: ChatMsg.say, message: 'Hello!');
await worldClient.sendMessage(chatType: ChatMsg.whisper, message: 'Hi', recipient: 'Arthas');

// 7. Keep session alive (blocking — handles ping, time sync, incoming packets)
await worldClient.keepSessionAlive();
```

---

## Architecture

```
lib/
├── authserver.dart              ← Public API: WowAuthClient
├── worldserver.dart             ← Public API: WorldClient + all exports
└── src/
    ├── transport/
    │   ├── i_transport.dart     ← ITransport interface (platform-agnostic)
    │   └── tcp_transport.dart   ← dart:io implementation
    ├── authserver/
    │   ├── auth_client.dart     ← WowAuthClient (SRP6 handshake, realm list)
    │   └── packets.dart
    ├── crypto/
    │   ├── srp6.dart            ← SRP6 protocol (BigInt arithmetic)
    │   ├── arc4.dart            ← ARC4/RC4 stream cipher
    │   └── utils.dart           ← SHA1, HMAC-SHA1 utilities
    └── worldserver/
        ├── worldclient.dart     ← WorldClient (thin facade — assembles mixins)
        ├── events/
        │   └── wow_event.dart   ← sealed class WowEvent hierarchy
        ├── core/
        │   └── world_client_base.dart  ← Shared state, ITransport, Stream<WowEvent>
        ├── models/
        │   ├── player_info.dart
        │   ├── world_auth_result.dart
        │   ├── world_connection_result.dart
        │   └── world_login_result.dart
        ├── mixins/
        │   ├── auth_mixin.dart     ← authenticate(), authenticateAndGetCharacters()
        │   ├── login_mixin.dart    ← loginToWorld()
        │   ├── session_mixin.dart  ← keepSessionAlive() + packet dispatch
        │   ├── chat_mixin.dart     ← sendMessage(), joinChannel(), leaveChannel()
        │   ├── guild_mixin.dart    ← getGuildRoster()
        │   └── who_mixin.dart      ← who(), requestPlayerName()
        ├── auth_crypt.dart      ← ARC4-drop1024 header encryption
        ├── auth_utils.dart      ← Auth digest (SHA1)
        ├── chat_enums.dart      ← ChatMsg, Language enums
        ├── opcodes/opcodes.dart ← All CMSG/SMSG opcodes
        └── packets/
            ├── client/          ← Outgoing packets
            └── server/          ← Incoming packet parsers

bin/
└── auth_client.dart             ← Interactive CLI tool
```

### Event types (`Stream<WowEvent>`)

| Event | Fields |
|-------|--------|
| `ChatMessageEvent` | `type`, `senderName`, `receiverName`, `message`, `channelName`, `language` |
| `MotdEvent` | `lines` |
| `GuildEvent` | `message` |
| `ServerMessageEvent` | `messageType`, `message` |
| `ChannelNotifyEvent` | `message` |
| `WhoResponseEvent` | `players`, `totalCount` |
| `GuildRosterUpdatedEvent` | `members` |
| `ConnectionClosedEvent` | — |
| `ConnectionErrorEvent` | `error` |

### Custom transport

Implement `ITransport` to use any network backend (WebSocket, pipe, mock):

```dart
class MyTransport implements ITransport {
  @override String get host => '...';
  @override int get port => 8085;
  @override Future<void> connect() async { ... }
  @override void send(Uint8List data) { ... }
  @override Stream<Uint8List> get dataStream => ...;
  @override Future<void> close() async { ... }
  @override bool get isConnected => ...;
}

final client = WorldClient(transport: MyTransport(), verbose: true);
```

### Protocol notes

- **Header format** — Client→Server: `uint16 size (BE) + uint32 opcode (LE)` / Server→Client: `uint16 size (BE) + uint16 opcode (LE)`
- **Encryption** — ARC4-drop1024 on headers only, derived via HMAC-SHA1 from 40-byte session key
- **Strings** — Always CString (bytes + `\0`), never length-prefixed
- **Auth flow** — SRP6 on port 3724 → session key → CMSG_AUTH_SESSION on port 8085

---

## Implemented Opcodes

### Authentication
| Opcode | Description |
|--------|-------------|
| `CMSG_AUTH_SESSION` | World server authentication |
| `SMSG_AUTH_CHALLENGE` | Server challenge |
| `SMSG_AUTH_RESPONSE` | Auth result |
| `SMSG_WARDEN_DATA` | Anti-cheat (ignored) |

### Session & Login
| Opcode | Description |
|--------|-------------|
| `CMSG_CHAR_ENUM` / `SMSG_CHAR_ENUM` | Character list |
| `CMSG_PLAYER_LOGIN` / `SMSG_LOGIN_VERIFY_WORLD` | Enter world |
| `CMSG_PING` / `SMSG_PONG` | Keepalive |
| `SMSG_TIME_SYNC_REQ` / `CMSG_TIME_SYNC_RESP` | Time sync |
| `CMSG_READY_FOR_ACCOUNT_DATA_TIMES` | Account data handshake |
| `MSG_MOVE_WORLDPORT_ACK` | Zone transfer ack |
| `SMSG_MOTD` | Message of the Day |

### Chat
| Opcode | Description |
|--------|-------------|
| `CMSG_MESSAGECHAT` | Send chat (SAY, YELL, WHISPER, GUILD, OFFICER, EMOTE, CHANNEL) |
| `SMSG_MESSAGECHAT` | Receive chat messages |
| `CMSG_NAME_QUERY` / `SMSG_NAME_QUERY_RESPONSE` | Player name resolution (with cache) |
| `CMSG_WHO` / `SMSG_WHO` | Online player search |
| `SMSG_CHAT_SERVER_MESSAGE` | Server broadcast messages |
| `SMSG_CHAT_PLAYER_NOT_FOUND` | Player not found error |
| `SMSG_CHAT_NOT_IN_PARTY` | Not in party error |
| `SMSG_CHAT_WRONG_FACTION` | Wrong faction error |
| `SMSG_CHAT_RESTRICTED` | Chat restricted error |
| `SMSG_GUILD_COMMAND_RESULT` | Guild command errors |

### Channels
| Opcode | Description |
|--------|-------------|
| `CMSG_JOIN_CHANNEL` | Join a chat channel |
| `CMSG_LEAVE_CHANNEL` | Leave a chat channel |
| `SMSG_CHANNEL_NOTIFY` | Channel events (joined, left, errors) |

### Guild
| Opcode | Description |
|--------|-------------|
| `SMSG_GUILD_EVENT` | Guild events (MOTD, member online/offline, promotions) |
| `CMSG_GUILD_ROSTER` / `SMSG_GUILD_ROSTER` | Guild member list |

---

## Future Features

### Tier 1 — Social / Chat
- [ ] **Friends list** — `SMSG_FRIEND_LIST`, `SMSG_FRIEND_STATUS`, `CMSG_ADD_FRIEND`, `CMSG_DEL_FRIEND`
- [ ] **Text emotes** — `SMSG_TEXT_EMOTE`
- [ ] **Ignore list** — `CMSG_ADD_IGNORE`, `CMSG_DEL_IGNORE`

### Tier 2 — Guild Management
- [ ] **Guild invite** — `CMSG_GUILD_INVITE`, `CMSG_GUILD_ACCEPT`, `CMSG_GUILD_DECLINE`
- [ ] **Guild admin** — `CMSG_GUILD_PROMOTE`, `CMSG_GUILD_KICK`, `CMSG_GUILD_LEAVE`
- [ ] **Guild MOTD** — `CMSG_GUILD_MOTD`

### Tier 3 — Group / Raid
- [ ] **Group invite** — `CMSG_GROUP_INVITE`, `CMSG_GROUP_ACCEPT`, `CMSG_GROUP_DECLINE`
- [ ] **Group management** — `CMSG_GROUP_UNINVITE`, `SMSG_GROUP_LIST`

### Tier 4 — Platform
- [ ] **WebSocket transport** — Flutter web support via TCP↔WebSocket proxy

---

## Dependencies

```yaml
dependencies:
  crypto: ^3.0.0   # SHA1, HMAC-SHA1
```

No native bindings. Single pure-Dart dependency.

---

*Compatible with AzerothCore 3.3.5a — opcodes verified against `src/server/game/Server/Protocol/Opcodes.h`*
