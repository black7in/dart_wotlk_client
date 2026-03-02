/// Simple command-line client for WoW 3.3.5a authentication
///
/// Usage: dart run bin/auth_client.dart <host> <port> <username> <password> [options]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_wotlk_client/authserver.dart';
import 'package:dart_wotlk_client/worldserver.dart';

Future<void> main(List<String> args) async {
  // Check for help flag
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    exit(0);
  }

  if (args.length < 4) {
    _printUsage();
    exit(1);
  }

  final host = args[0];
  final port = int.parse(args[1]);
  final username = args[2];
  final password = args[3];

  // Optional: Enable verbose mode with -v or --verbose flag
  final verbose = args.contains('-v') || args.contains('--verbose');

  if (verbose) {
    print('═══════════════════════════════════════════════════');
    print('  WoW 3.3.5a Authentication Client');
    print('═══════════════════════════════════════════════════');
    print('Server: $host:$port');
    print('Username: $username');
    print('═══════════════════════════════════════════════════\n');
  }

  // Create auth client
  final client = WowAuthClient(
    host: host,
    port: port,
    verbose: verbose,
  );

  // Attempt authentication
  final result = await client.authenticate(
    username: username,
    password: password,
    connectionDelay: Duration(milliseconds: 100),
    requestRealms: true,
  );

  // Print result
  print('═══════════════════════════════════════════════════');
  if (result.success) {
    print('✓ AUTHENTICATION SUCCESSFUL');
    if (verbose) {
      print('Session Key: ${result.sessionKey!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    }
    print('═══════════════════════════════════════════════════');

    // Display realm list if available
    if (result.realms != null && result.realms!.isNotEmpty) {
      print('');
      print('═══════════════════════════════════════════════════');
      print('✓ REALM LIST (${result.realms!.length} realms)');
      print('═══════════════════════════════════════════════════');

      for (int i = 0; i < result.realms!.length; i++) {
        final realm = result.realms![i];
        print('');
        print('Realm #${i + 1}:');
        print('  Name:       ${realm.name}');
        print('  Type:       ${realm.typeString}');
        print('  Address:    ${realm.address}');
        print('  Status:     ${realm.isOnline ? "Online" : "Offline"}');
        print('  Population: ${(realm.population * 100).toStringAsFixed(0)}%');
        print('  Characters: ${realm.characterCount}');

        final flags = <String>[];
        if (realm.isRecommended) flags.add('Recommended');
        if (realm.isNew) flags.add('New');
        if (realm.isFull) flags.add('Full');
        if (flags.isNotEmpty) {
          print('  Flags:      ${flags.join(", ")}');
        }
      }
      print('═══════════════════════════════════════════════════');
    }

    // Try to connect to the first available realm
    if (result.realms != null && result.realms!.isNotEmpty) {
      final firstRealm = result.realms!.first;

      if (firstRealm.isOnline) {
        print('');
        print('═══════════════════════════════════════════════════');
        print('  CONNECTING TO WORLD SERVER');
        print('═══════════════════════════════════════════════════');
        print('Realm: ${firstRealm.name}');

        // Parse address (format: "127.0.0.1:8085")
        final addressParts = firstRealm.address.split(':');
        final worldHost = addressParts[0];
        final worldPort = int.parse(addressParts[1]);

        print('Address: $worldHost:$worldPort');
        print('');

        // Create world client with TCP transport
        final worldClient = WorldClient(
          transport: TcpTransport(host: worldHost, port: worldPort),
          verbose: verbose,
        );

        // Wire up event listener for all server events
        worldClient.events.listen((event) {
          switch (event) {
            case ChatMessageEvent e:
              print(_formatChatMessage(e));
            case GuildEvent e:
              print(e.message);
            case ServerMessageEvent e:
              print('\n╔═══════════════════════════════════════════════════╗');
              print('║ ${e.messageType.padRight(48)} ║');
              print('╠═══════════════════════════════════════════════════╣');
              for (final line in _wrapText(e.message, 48)) {
                print('║ ${line.padRight(48)} ║');
              }
              print('╚═══════════════════════════════════════════════════╝\n');
            case MotdEvent e:
              if (e.lines.isNotEmpty) {
                print('\n╔═══════════════════════════════════════════════════╗');
                print('║           MESSAGE OF THE DAY (MOTD)              ║');
                print('╠═══════════════════════════════════════════════════╣');
                for (final line in e.lines) {
                  for (final wrapped in _wrapText(line, 48)) {
                    print('║ ${wrapped.padRight(48)} ║');
                  }
                }
                print('╚═══════════════════════════════════════════════════╝\n');
              }
            case ChannelNotifyEvent e:
              print(e.message);
            case GuildRosterUpdatedEvent _:
              // silently stored in client; user can call /groster to display
              break;
            case WhoResponseEvent _:
              // handled via the Future returned by worldClient.who()
              break;
            case ConnectionClosedEvent _:
              print('\nConnection closed by server.');
            case ConnectionErrorEvent e:
              print('\nConnection error: ${e.error}');
          }
        });

        // Authenticate with world server AND get character list
        final worldResult = await worldClient.authenticateAndGetCharacters(
          accountName: username,
          sessionKey: result.sessionKey!,
          realmId: firstRealm.id,
          connectionDelay: Duration(milliseconds: 100),
        );

        print('═══════════════════════════════════════════════════');
        if (worldResult.success) {
          print('✓ WORLD SERVER CONNECTION SUCCESSFUL');
          print('Message: ${worldResult.message}');
          print('═══════════════════════════════════════════════════');

          // Display character list
          if (worldResult.characters != null && worldResult.characters!.isNotEmpty) {
            print('');
            print('═══════════════════════════════════════════════════');
            print('  CHARACTER LIST');
            print('═══════════════════════════════════════════════════');

            for (int i = 0; i < worldResult.characters!.length; i++) {
              final char = worldResult.characters![i];
              print('');
              print('Character #${i + 1}:');
              print('  Name:     ${char.name}');
              print('  Level:    ${char.level}');
              print('  Race:     ${char.raceName}');
              print('  Class:    ${char.className}');
              print('  Gender:   ${char.genderName}');
              print('  Zone:     ${char.zone}');
              print('  Map:      ${char.map}');
              print('  Position: (${char.x.toStringAsFixed(2)}, ${char.y.toStringAsFixed(2)}, ${char.z.toStringAsFixed(2)})');

              if (char.guildId > 0) {
                print('  Guild ID: ${char.guildId}');
              }

              if (char.petDisplayId > 0) {
                print('  Pet:      Level ${char.petLevel} (Family: ${char.petFamily})');
              }

              if (char.firstLogin) {
                print('  Status:   First login');
              }

              if (verbose) {
                print('  GUID:     ${char.guid}');
                print('  Flags:    0x${char.characterFlags.toRadixString(16)}');
              }
            }
            print('═══════════════════════════════════════════════════');

            // Ask user to select a character
            print('');
            print('Select a character to login (1-${worldResult.characters!.length}) or 0 to exit:');
            stdout.write('> ');
            await stdout.flush();

            try {
              stdin.echoMode = true;
              stdin.lineMode = true;
            } catch (e) {
              // Ignore on systems where this isn't supported
            }

            final selectionCompleter = Completer<int>();
            var isSelectingCharacter = true;
            WorldLoginResult? loginResult;

            final stdinSub = stdin
                .transform(SystemEncoding().decoder)
                .transform(LineSplitter())
                .listen((input) async {
              if (isSelectingCharacter) {
                if (input.trim().isEmpty) {
                  print('No selection made. Exiting...');
                  await worldClient.transport.close();
                  exit(0);
                }

                final selection = int.tryParse(input.trim());
                if (selection == null || selection < 0 || selection > worldResult.characters!.length) {
                  print('Invalid selection. Exiting...');
                  await worldClient.transport.close();
                  exit(1);
                }

                if (selection == 0) {
                  print('Exiting...');
                  await worldClient.transport.close();
                  exit(0);
                }

                selectionCompleter.complete(selection);
              } else {
                // Handle chat commands (only after login)
                if (loginResult == null) return;

                final line = input.trim();
                if (line.isEmpty) return;

                if (line.startsWith('/quit')) {
                  print('Disconnecting...');
                  await worldClient.transport.close();
                } else if (line.startsWith('/say ')) {
                  final msg = line.substring(5);
                  try {
                    await worldClient.sendMessage(chatType: ChatMsg.say, message: msg);
                  } catch (e) {
                    print('Error sending message: $e');
                  }
                } else if (line.startsWith('/yell ')) {
                  final msg = line.substring(6);
                  try {
                    await worldClient.sendMessage(chatType: ChatMsg.yell, message: msg);
                  } catch (e) {
                    print('Error sending message: $e');
                  }
                } else if (line.startsWith('/w ')) {
                  final parts = line.substring(3).split(' ');
                  if (parts.length < 2) {
                    print('Usage: /w <player> <message>');
                    return;
                  }
                  final recipient = parts[0];
                  final msg = parts.skip(1).join(' ');
                  try {
                    await worldClient.sendMessage(
                      chatType: ChatMsg.whisper,
                      message: msg,
                      recipient: recipient,
                    );
                  } catch (e) {
                    print('Error sending whisper: $e');
                  }
                } else if (line.startsWith('/guild ')) {
                  final msg = line.substring(7);
                  try {
                    await worldClient.sendMessage(chatType: ChatMsg.guild, message: msg);
                  } catch (e) {
                    print('Error sending guild message: $e');
                  }
                } else if (line.startsWith('/officer ')) {
                  final msg = line.substring(9);
                  try {
                    await worldClient.sendMessage(chatType: ChatMsg.officer, message: msg);
                  } catch (e) {
                    print('Error sending officer message: $e');
                  }
                } else if (line.startsWith('/emote ')) {
                  final msg = line.substring(7);
                  try {
                    await worldClient.sendMessage(chatType: ChatMsg.emote, message: msg);
                  } catch (e) {
                    print('Error sending emote: $e');
                  }
                } else if (line.startsWith('/who')) {
                  final parts = line.split(' ');
                  try {
                    List<WhoPlayerInfo> players;
                    if (parts.length == 1) {
                      print('Querying online players...');
                      players = await worldClient.who();
                    } else {
                      final query = parts.sublist(1).join(' ');
                      print('Searching for "$query"...');
                      players = await worldClient.who(name: query);
                    }

                    if (players.isEmpty) {
                      print('No players found.');
                    } else {
                      print('');
                      print('═══════════════════════════════════════════════════');
                      print('Online Players (${players.length}):');
                      print('═══════════════════════════════════════════════════');
                      for (final player in players) {
                        print(player);
                      }
                      print('═══════════════════════════════════════════════════');
                      print('');
                    }
                  } catch (e) {
                    print('Error querying WHO: $e');
                  }
                } else if (line.startsWith('/join ')) {
                  final rest = line.substring(6).trim();
                  final parts = rest.split(' ');
                  final channelName = parts[0];
                  final password = parts.length > 1 ? parts[1] : '';
                  try {
                    await worldClient.joinChannel(channelName: channelName, password: password);
                  } catch (e) {
                    print('Error joining channel: $e');
                  }
                } else if (line.startsWith('/leave ')) {
                  final channelName = line.substring(7).trim();
                  try {
                    await worldClient.leaveChannel(channelName: channelName);
                  } catch (e) {
                    print('Error leaving channel: $e');
                  }
                } else if (line.startsWith('/ch ')) {
                  final rest = line.substring(4).trim();
                  final spaceIdx = rest.indexOf(' ');
                  if (spaceIdx == -1) {
                    print('Usage: /ch <channel> <message>');
                    return;
                  }
                  final channelName = rest.substring(0, spaceIdx);
                  final msg = rest.substring(spaceIdx + 1);
                  try {
                    await worldClient.sendMessage(
                      chatType: ChatMsg.channel,
                      message: msg,
                      channelName: channelName,
                    );
                  } catch (e) {
                    print('Error sending channel message: $e');
                  }
                } else if (line.startsWith('/groster')) {
                  try {
                    print('Requesting guild roster...');
                    final members = await worldClient.getGuildRoster();
                    _printGuildRoster(members);
                  } catch (e) {
                    print('Error getting guild roster: $e');
                  }
                } else {
                  print('Unknown command. Type /say, /yell, /w, /guild, /officer, /emote, /who, /join, /leave, /ch, /groster, or /quit');
                }
              }
            });

            // Wait for character selection
            final selection = await selectionCompleter.future;
            isSelectingCharacter = false;

            final selectedChar = worldResult.characters![selection - 1];
            print('');
            print('═══════════════════════════════════════════════════');
            print('  LOGGING IN WITH: ${selectedChar.name}');
            print('═══════════════════════════════════════════════════');

            loginResult = await worldClient.loginToWorld(
              characterGuid: selectedChar.guid,
            );

            if (loginResult.success) {
              print('');
              print('═══════════════════════════════════════════════════');
              print('✓ SUCCESSFULLY ENTERED THE WORLD');
              print('═══════════════════════════════════════════════════');

              if (loginResult.verifyWorld != null) {
                print('Map:         ${loginResult.verifyWorld!.mapName}');
                print('Position:    (${loginResult.verifyWorld!.positionX.toStringAsFixed(2)}, ${loginResult.verifyWorld!.positionY.toStringAsFixed(2)}, ${loginResult.verifyWorld!.positionZ.toStringAsFixed(2)})');
                print('Orientation: ${loginResult.verifyWorld!.orientation.toStringAsFixed(2)}');
              }

              print('');
              print('Session is now ACTIVE. Press Ctrl+C to disconnect.');
              print('');
              print('Chat commands:');
              print('  /say <message>             - Say to nearby players');
              print('  /yell <message>            - Yell to zone');
              print('  /w <player> <message>      - Whisper to player');
              print('  /guild <message>           - Guild chat');
              print('  /officer <message>         - Officer chat');
              print('  /emote <message>           - Perform emote');
              print('  /who [name|guild]          - List online players');
              print('  /join <channel> [password] - Join a chat channel');
              print('  /leave <channel>           - Leave a chat channel');
              print('  /ch <channel> <message>    - Send message to channel');
              print('  /groster                   - Show guild member list');
              print('  /quit                      - Disconnect');
              print('═══════════════════════════════════════════════════');
              print('');

              // Keep session alive (blocks until connection closes)
              await worldClient.keepSessionAlive(
                onPacketReceived: (opcodeName, opcodeValue, payload) {
                  if (verbose && !opcodeName.startsWith('UNKNOWN')) {
                    print('[Received] $opcodeName (0x${opcodeValue.toRadixString(16).padLeft(4, '0')}) - ${payload.length} bytes');
                  }
                },
              );

              await stdinSub.cancel();

              print('');
              print('Session ended.');
              await worldClient.transport.close();
            } else {
              print('');
              print('✗ FAILED TO ENTER THE WORLD');
              print('Error: ${loginResult.message}');
              if (loginResult.errorCode != null) {
                print('Code: ${loginResult.errorCode}');
              }
              await worldClient.transport.close();
              exit(1);
            }
          } else if (worldResult.characters != null && worldResult.characters!.isEmpty) {
            print('');
            print('No characters found on this realm');
            print('═══════════════════════════════════════════════════');
          }
        } else {
          print('✗ WORLD SERVER CONNECTION FAILED');
          print('Error: ${worldResult.message}');
          if (verbose && worldResult.errorCode != null) {
            print('Code: ${worldResult.errorCode}');
          }
          print('═══════════════════════════════════════════════════');
        }
      }
    }

    exit(0);
  } else {
    print('✗ AUTHENTICATION FAILED');
    print('Error: ${result.message}');
    if (verbose) {
      print('Code: ${result.errorCode}');
    }
    print('═══════════════════════════════════════════════════');
    exit(1);
  }
}

String _formatChatMessage(ChatMessageEvent e) {
  final sender = e.senderName;
  final text = e.message;
  switch (e.type) {
    case ChatMsg.say:
      return '[Say] $sender: $text';
    case ChatMsg.yell:
      return '[Yell] $sender: $text';
    case ChatMsg.whisper:
      return '[Whisper from $sender]: $text';
    case ChatMsg.whisperInform:
      return '[Whisper to ${e.receiverName ?? 'Unknown'}]: $text';
    case ChatMsg.guild:
      return '[Guild] $sender: $text';
    case ChatMsg.officer:
      return '[Officer] $sender: $text';
    case ChatMsg.party:
      return '[Party] $sender: $text';
    case ChatMsg.partyLeader:
      return '[Party Leader] $sender: $text';
    case ChatMsg.raid:
      return '[Raid] $sender: $text';
    case ChatMsg.raidLeader:
      return '[Raid Leader] $sender: $text';
    case ChatMsg.raidWarning:
      return '[Raid Warning] $sender: $text';
    case ChatMsg.channel:
      return '[${e.channelName ?? 'Channel'}] $sender: $text';
    case ChatMsg.emote:
      return '[Emote] $sender $text';
    case ChatMsg.textEmote:
      return '[Text Emote] $sender $text';
    case ChatMsg.system:
      return '[System] $text';
    case ChatMsg.monsterSay:
      return '[NPC Say] $sender: $text';
    case ChatMsg.monsterYell:
      return '[NPC Yell] $sender: $text';
    case ChatMsg.monsterEmote:
      return '[NPC Emote] $sender $text';
    case ChatMsg.achievement:
      return '[Achievement] $sender: $text';
    case ChatMsg.guildAchievement:
      return '[Guild Achievement] $sender: $text';
    default:
      final typeName = e.type?.displayName ?? 'Unknown';
      return '[$typeName] $sender: $text';
  }
}

List<String> _wrapText(String text, int width) {
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

void _printGuildRoster(List<GuildMemberInfo> members) {
  if (members.isEmpty) {
    print('No guild members found (or not in a guild).');
    return;
  }
  final online = members.where((m) => m.online).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final offline = members.where((m) => !m.online).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  print('');
  print('═══════════════════════════════════════════════════');
  print('  GUILD MEMBERS (${members.length} total, ${online.length} online)');
  print('═══════════════════════════════════════════════════');
  if (online.isNotEmpty) {
    print('  Online (${online.length}):');
    for (final m in online) {
      final note = m.note.isNotEmpty ? '  "${m.note}"' : '';
      print('    [${m.rankId}] ${m.name}  Lv.${m.level} ${m.className}$note');
    }
  }
  if (offline.isNotEmpty) {
    print('  Offline (${offline.length}):');
    for (final m in offline) {
      final note = m.note.isNotEmpty ? '  "${m.note}"' : '';
      print('    [${m.rankId}] ${m.name}  Lv.${m.level} ${m.className}  ${m.lastSeenString}$note');
    }
  }
  print('═══════════════════════════════════════════════════');
  print('');
}

void _printUsage() {
  print('WoW 3.3.5a Authentication Client');
  print('');
  print('Usage: dart run bin/auth_client.dart <host> <port> <username> <password> [options]');
  print('');
  print('Options:');
  print('  -v, --verbose    Enable verbose output (shows packets and session key)');
  print('  -h, --help       Show this help message');
  print('');
  print('Examples:');
  print('  dart run bin/auth_client.dart 127.0.0.1 3724 myaccount mypassword');
  print('  dart run bin/auth_client.dart 127.0.0.1 3724 myaccount mypassword -v');
}
