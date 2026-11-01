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

/// Pure number crunching for insights and reports.
class Analytics {
  Analytics._();

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
