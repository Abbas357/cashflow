import '../data/models/models.dart';

/// Money in and out over one stretch of time.
class Bucket {
  final DateTime start;
  final String label;
  double cashIn = 0;
  double cashOut = 0;
  int count = 0;

  /// Balance at the end of the bucket, across all earlier entries too.
  double closing = 0;

  Bucket(this.start, this.label);

  double get net => cashIn - cashOut;

  void add(Entry e) {
    if (e.isIn) {
      cashIn += e.amount;
    } else {
      cashOut += e.amount;
    }
    count++;
  }
}

enum Grouping { day, month, year }

/// Pure number crunching for summaries, insights and reports.
class Analytics {
  Analytics._();

  static DateTime keyOf(DateTime d, Grouping g) => switch (g) {
    Grouping.day => DateTime(d.year, d.month, d.day),
    Grouping.month => DateTime(d.year, d.month),
    Grouping.year => DateTime(d.year),
  };

  /// Groups [entries] (any order) by day, month or year, newest first, with
  /// the closing balance of each group.
  static List<Bucket> group(
    List<Entry> entries,
    Grouping g,
    String Function(DateTime) label,
  ) {
    final sorted = [...entries]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final map = <DateTime, Bucket>{};
    var running = 0.0;
    for (final e in sorted) {
      final k = keyOf(e.occurredAt, g);
      final b = map[k] ??= Bucket(k, label(k));
      b.add(e);
      running += e.signed;
      b.closing = running;
    }
    return map.values.toList().reversed.toList();
  }

  /// The last [months] calendar months ending with the current one, oldest
  /// first, including empty months so a chart has no gaps.
  static List<Bucket> lastMonths(
    List<Entry> entries,
    int months,
    String Function(DateTime) label, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final buckets = [
      for (var i = months - 1; i >= 0; i--)
        Bucket(DateTime(n.year, n.month - i), label(DateTime(n.year, n.month - i))),
    ];
    final first = buckets.first.start;
    var opening = 0.0;
    for (final e in entries) {
      if (e.occurredAt.isBefore(first)) {
        opening += e.signed;
        continue;
      }
      final k = DateTime(e.occurredAt.year, e.occurredAt.month);
      for (final b in buckets) {
        if (b.start == k) {
          b.add(e);
          break;
        }
      }
    }
    var running = opening;
    for (final b in buckets) {
      running += b.net;
      b.closing = running;
    }
    return buckets;
  }

  /// Where the money went: cash out grouped by note, largest first.
  /// Notes are the categories people already type ("Milk", "Fare").
  static List<(String, double, int)> topSpending(List<Entry> entries, {int limit = 8}) {
    final map = <String, (String, double, int)>{};
    for (final e in entries) {
      if (e.isIn || e.transferId != null) continue;
      final name = e.note.trim().isEmpty ? 'No note' : e.note.trim();
      final key = name.toLowerCase();
      final cur = map[key];
      map[key] = (cur?.$1 ?? name, (cur?.$2 ?? 0) + e.amount, (cur?.$3 ?? 0) + 1);
    }
    final list = map.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(limit).toList();
  }

  /// Total cash out on each weekday, Monday first.
  static List<double> byWeekday(List<Entry> entries) {
    final out = List<double>.filled(7, 0);
    for (final e in entries) {
      if (!e.isIn && e.transferId == null) out[e.occurredAt.weekday - 1] += e.amount;
    }
    return out;
  }
}
