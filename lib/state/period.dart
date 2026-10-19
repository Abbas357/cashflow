import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// The time windows the ledger can show.
enum PeriodKind {
  all('All'),
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly'),
  custom('Range');

  final String label;
  const PeriodKind(this.label);
}

/// A window of time: a kind plus the date it is anchored on.
class Period {
  final PeriodKind kind;
  final DateTime anchor;
  final DateTimeRange? range;
  final int weekStart;

  const Period({
    required this.kind,
    required this.anchor,
    this.range,
    this.weekStart = DateTime.monday,
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Inclusive start, exclusive end. Null for "All".
  (DateTime, DateTime)? get bounds {
    final a = _day(anchor);
    switch (kind) {
      case PeriodKind.all:
        return null;
      case PeriodKind.daily:
        return (a, DateTime(a.year, a.month, a.day + 1));
      case PeriodKind.weekly:
        final back = (a.weekday - weekStart + 7) % 7;
        final start = DateTime(a.year, a.month, a.day - back);
        return (start, DateTime(start.year, start.month, start.day + 7));
      case PeriodKind.monthly:
        return (DateTime(a.year, a.month), DateTime(a.year, a.month + 1));
      case PeriodKind.yearly:
        return (DateTime(a.year), DateTime(a.year + 1));
      case PeriodKind.custom:
        final r = range!;
        final end = _day(r.end);
        return (_day(r.start), DateTime(end.year, end.month, end.day + 1));
    }
  }

  bool contains(DateTime d) {
    final b = bounds;
    if (b == null) return true;
    return !d.isBefore(b.$1) && d.isBefore(b.$2);
  }

  bool get canStep => kind != PeriodKind.all && kind != PeriodKind.custom;

  Period step(int by) {
    final a = anchor;
    final next = switch (kind) {
      PeriodKind.daily => DateTime(a.year, a.month, a.day + by),
      PeriodKind.weekly => DateTime(a.year, a.month, a.day + 7 * by),
      PeriodKind.monthly => DateTime(a.year, a.month + by, 1),
      PeriodKind.yearly => DateTime(a.year + by, 1, 1),
      _ => a,
    };
    return Period(kind: kind, anchor: next, range: range, weekStart: weekStart);
  }

  String get label {
    final b = bounds;
    switch (kind) {
      case PeriodKind.all:
        return 'All time';
      case PeriodKind.daily:
        return Fmt.relativeDay(anchor);
      case PeriodKind.weekly:
        final end = b!.$2.subtract(const Duration(days: 1));
        return '${Fmt.dayShort(b.$1)}  to  ${Fmt.dayShort(end)}';
      case PeriodKind.monthly:
        return Fmt.month(anchor);
      case PeriodKind.yearly:
        return '${anchor.year}';
      case PeriodKind.custom:
        final end = b!.$2.subtract(const Duration(days: 1));
        return '${Fmt.dayShort(b.$1)}  to  ${Fmt.dayShort(end)}';
    }
  }
}
