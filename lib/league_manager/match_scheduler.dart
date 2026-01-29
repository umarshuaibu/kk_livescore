// matchDays format: "weekdayIndex|HH:mm" e.g. "5|16:00" (5 = Friday)

List<DateTime> scheduleMatches({
  required DateTime startDate,
  required List<String> matchDays,
  required int totalMatches,
}) {
  if (matchDays.isEmpty || totalMatches <= 0) return [];

  /// -------------------------------
  /// PARSE & VALIDATE SLOTS
  /// -------------------------------
  final List<_MatchSlot> slots = [];

  for (final md in matchDays) {
    final parts = md.split('|');
    if (parts.length != 2) continue;

    final weekday = int.tryParse(parts[0]);
    if (weekday == null || weekday < 1 || weekday > 7) continue;

    final time = parts[1].split(':');
    if (time.length != 2) continue;

    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);

    if (hour == null || minute == null) continue;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;

    slots.add(_MatchSlot(
      weekday: weekday,
      hour: hour,
      minute: minute,
    ));
  }

  if (slots.isEmpty) return [];

  /// Sort slots within a week (Mon → Sun, time)
  slots.sort((a, b) {
    final w = a.weekday.compareTo(b.weekday);
    if (w != 0) return w;
    final h = a.hour.compareTo(b.hour);
    if (h != 0) return h;
    return a.minute.compareTo(b.minute);
  });

  /// -------------------------------
  /// STRICTLY FORWARD SCHEDULING
  /// -------------------------------
  final List<DateTime> scheduled = [];
  DateTime cursor = startDate;

  while (scheduled.length < totalMatches) {
    DateTime? nextMatch;

    for (final slot in slots) {
      DateTime candidate = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        slot.hour,
        slot.minute,
      );

      int daysToAdd = slot.weekday - candidate.weekday;
      if (daysToAdd < 0) daysToAdd += 7;

      candidate = candidate.add(Duration(days: daysToAdd));

      /// MUST be strictly after cursor
      if (!candidate.isAfter(cursor)) {
        candidate = candidate.add(const Duration(days: 7));
      }

      if (nextMatch == null || candidate.isBefore(nextMatch)) {
        nextMatch = candidate;
      }
    }

    if (nextMatch == null) break;

    scheduled.add(nextMatch);

    /// Move cursor forward — NEVER backward
    cursor = nextMatch;
  }

  return scheduled;
}

/// -------------------------------
/// SLOT MODEL
/// -------------------------------
class _MatchSlot {
  final int weekday;
  final int hour;
  final int minute;

  const _MatchSlot({
    required this.weekday,
    required this.hour,
    required this.minute,
  });
}
