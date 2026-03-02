/// Player information from NAME_QUERY
class PlayerInfo {
  final int guid;
  final String name;
  final int race;
  final int gender;
  final int classId;
  final String? realmName;

  PlayerInfo({
    required this.guid,
    required this.name,
    required this.race,
    required this.gender,
    required this.classId,
    this.realmName,
  });
}
