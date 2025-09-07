import 'match_day_model.dart';
class League {
  final String id;
  final String name;
  final String system; // e.g. "super_six" or "super_four"
  final List<String> participatingTeamIds;
  final List<MatchDay> matchDays;
  final DateTime startDate;
  final DateTime createdAt;

  League({
    required this.id,
    required this.name,
    required this.system,
    required this.participatingTeamIds,
    required this.matchDays,
    required this.startDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'system': system,
      'participatingTeamIds': participatingTeamIds,
      'matchDays': matchDays.map((day) => day.toMap()).toList(),
      'startDate': startDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory League.fromMap(Map<String, dynamic> map) {
    return League(
      id: map['id'],
      name: map['name'],
      system: map['system'],
      participatingTeamIds: List<String>.from(map['participatingTeamIds']),
      matchDays: List<Map<String, dynamic>>.from(map['matchDays'])
          .map((e) => MatchDay.fromMap(e))
          .toList(),
      startDate: DateTime.parse(map['startDate']),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}