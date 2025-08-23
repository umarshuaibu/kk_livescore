class Team {
  final String id;
  final String name;
  final String abbr;
  final String? coachId;
  final String? logoUrl;
  final List<String> players;

  Team({
    required this.id,
    required this.name,
    required this.abbr,
    this.coachId,
    this.logoUrl,
    required this.players,
  });

  // Convert Team object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbr': abbr,
      'coachId': coachId,
      'logoUrl': logoUrl,
      'players': players,
    };
  }

  // Create Team object from Map (e.g., Firestore data)
  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] as String,
      name: map['name'] as String,
      abbr: map['abbr'] as String,
      coachId: map['coachId'] as String?,
      logoUrl: map['logoUrl'] as String?,
      players: List<String>.from(map['players'] ?? []),
    );
  }
}