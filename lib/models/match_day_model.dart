class MatchDay {
  final String day; // e.g. "Saturday"
  final List<String> times; // e.g. ["10:00 AM", "4:00 PM"]

  MatchDay({
    required this.day,
    required this.times,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'times': times,
    };
  }

  factory MatchDay.fromMap(Map<String, dynamic> map) {
    return MatchDay(
      day: map['day'],
      times: List<String>.from(map['times']),
    );
  }
}
