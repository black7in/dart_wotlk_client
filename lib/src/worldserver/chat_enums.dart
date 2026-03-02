/// Chat message types
/// From src/server/shared/SharedDefines.h (enum ChatMsg)
enum ChatMsg {
  say(0x01),
  yell(0x06),
  whisper(0x07),
  whisperInform(0x09),
  emote(0x0A),
  textEmote(0x0B),
  guild(0x04),
  officer(0x05),
  party(0x02),
  raid(0x03),
  channel(0x11),
  afk(0x17),
  dnd(0x18),
  battleground(0x2C),
  raidLeader(0x27),
  raidWarning(0x28),
  partyLeader(0x33),
  battlegroundLeader(0x2D),
  // Additional types for receiving messages
  system(0x00),
  monsterSay(0x0C),
  monsterYell(0x0E),
  monsterEmote(0x10),
  achievement(0x30),
  guildAchievement(0x31);

  const ChatMsg(this.value);
  final int value;

  String get displayName {
    switch (this) {
      case ChatMsg.say: return 'Say';
      case ChatMsg.yell: return 'Yell';
      case ChatMsg.whisper: return 'Whisper';
      case ChatMsg.whisperInform: return 'Whisper (sent)';
      case ChatMsg.guild: return 'Guild';
      case ChatMsg.officer: return 'Officer';
      case ChatMsg.party: return 'Party';
      case ChatMsg.raid: return 'Raid';
      case ChatMsg.channel: return 'Channel';
      case ChatMsg.emote: return 'Emote';
      case ChatMsg.textEmote: return 'Text Emote';
      case ChatMsg.system: return 'System';
      case ChatMsg.achievement: return 'Achievement';
      case ChatMsg.guildAchievement: return 'Guild Achievement';
      default: return toString().split('.').last;
    }
  }
}

/// Languages supported by the game
/// From src/server/shared/SharedDefines.h (enum Language)
enum Language {
  universal(0),
  orcish(1),
  darnassian(2),
  taurahe(3),
  dwarvish(6),
  common(7),
  thalassian(10),
  gnomish(13),
  troll(14),
  gutterspeak(33),
  draenei(35);

  const Language(this.value);
  final int value;

  String get displayName {
    switch (this) {
      case Language.universal: return 'Universal';
      case Language.common: return 'Common';
      case Language.orcish: return 'Orcish';
      case Language.darnassian: return 'Darnassian';
      case Language.taurahe: return 'Taurahe';
      case Language.dwarvish: return 'Dwarvish';
      case Language.thalassian: return 'Thalassian';
      case Language.gnomish: return 'Gnomish';
      case Language.troll: return 'Troll';
      case Language.gutterspeak: return 'Gutterspeak';
      case Language.draenei: return 'Draenei';
    }
  }
}
