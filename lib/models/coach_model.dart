class Coach {
  final String id;
  final String name;
  final String? team;
  final String? photoUrl;

  Coach({
    required this.id,
    required this.name,
    this.team,
    this.photoUrl,
  });

  // Convert Coach object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'team': team,
      'photoUrl': photoUrl,
    };
  }

  // Create Coach object from Map (e.g., Firestore data)
  factory Coach.fromMap(Map<String, dynamic> map) {
    return Coach(
      id: map['id'] as String,
      name: map['name'] as String,
      team: map['team'] as String?,
      photoUrl: map['photoUrl'] as String?,
    );
  }
}