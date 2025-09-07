class GroupModel {
  final String id;
  final String leagueId;
  final String name; // e.g. "Group A"
  final List<String> teamIds;

  GroupModel({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.teamIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leagueId': leagueId,
      'name': name,
      'teamIds': teamIds,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'],
      leagueId: map['leagueId'],
      name: map['name'],
      teamIds: List<String>.from(map['teamIds']),
    );
  }
}