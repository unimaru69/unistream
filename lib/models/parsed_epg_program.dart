/// A parsed EPG program with DateTime fields, ready for display.
///
/// Unlike [EpgProgram] which stores raw API strings, this class holds
/// pre-parsed DateTime values and decoded titles for direct use in UI.
class ParsedEpgProgram {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final String startServerLocal;
  final DateTime? startUtc;

  const ParsedEpgProgram({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.startServerLocal = '',
    this.startUtc,
  });

  int get durationMin => end.difference(start).inMinutes;

  bool get isPast => DateTime.now().isAfter(end);

  bool get isCurrent =>
      DateTime.now().isAfter(start) && DateTime.now().isBefore(end);

  bool get isFuture => !isPast && !isCurrent;

  String get timeRange =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
      ' \u2014 ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}
