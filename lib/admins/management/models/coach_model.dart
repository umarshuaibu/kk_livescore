class Coach {
  final String id;
  final String name;
  final String? teamId;
    final String? teamName;
  final String? photoUrl;
  final DateTime? dateOfBirth; // New field

  Coach({
    required this.id,
    required this.name,
    this.teamId,
    this.teamName,
    this.photoUrl,
    this.dateOfBirth,
  });

  // Convert Coach object to Map for Firestore
 Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teamId': teamId,
      'teamName': teamName,
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth?.toIso8601String(), // Save as string
    };
  }

  // Convert Coach to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teamId': teamId,
      'teamName': teamName,
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth?.toIso8601String(), // Convert DateTime to string for Firestore
    };
  }
  

  // Create Coach object from Map (e.g., Firestore data)
  factory Coach.fromMap(Map<String, dynamic> map) {
    return Coach(
      id: map['id'] as String,
      name: map['name'] as String,
      teamId: map['teamId'] as String?,
      teamName: map['teamName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'] as String)
          : null,
    );
  }

  static empty() {}
}
