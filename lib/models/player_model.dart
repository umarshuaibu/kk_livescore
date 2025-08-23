class Player {
  final String id;
  final String name;
  final String position;
  final int jerseyNo;
  final String? team; // Changed to nullable
  final String playerPhoto;

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.jerseyNo,
    this.team, // Optional parameter
    required this.playerPhoto,
  });

  // Named constructor for creating a player from a map (e.g., from JSON)
  Player.fromMap(Map<String, dynamic> map)
      : id = map['id'] as String,
        name = map['name'] as String,
        position = map['position'] as String,
        jerseyNo = map['jerseyNo'] as int,
        team = map['team'] as String?, // Nullable team
        playerPhoto = map['playerPhoto'] as String;

  // Method to convert Player to a map (e.g., for JSON serialization)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'jerseyNo': jerseyNo,
      'team': team, // Will be null if not assigned
      'playerPhoto': playerPhoto,
    };
  }
}