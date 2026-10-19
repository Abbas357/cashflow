import 'package:intl/intl.dart';

/// How large numbers are grouped: 4,78,940 (lakh) or 478,940 (million).
enum NumberGrouping { lakh, million }

/// Turns amounts and dates into text, following the user's settings.
class Fmt {
  Fmt._();

  static String currency = '';
  static NumberGrouping grouping = NumberGrouping.lakh;
  static int decimals = 0;

  static NumberFormat get _number {
    final fraction = decimals == 0 ? '' : '.${'0' * decimals}';
    final optional = decimals == 0 ? '.##' : '';
    return grouping == NumberGrouping.lakh
        ? NumberFormat('#,##,##0$fraction$optional', 'en_IN')
        : NumberFormat('#,##0$fraction$optional', 'en_US');
  }

  /// 4,78,940 or 4,78,940.50 (no currency symbol).
  static String number(num value) => _number.format(value);

  /// Rs 4,78,940 when a currency symbol is set.
  static String money(num value, {bool signed = false}) {
    final sign = value < 0 ? '-' : (signed && value > 0 ? '+' : '');
    final body = number(value.abs());
    return currency.isEmpty ? '$sign$body' : '$sign$currency $body';
  }

  /// Short form for chart axes: 1.2K, 3.4L / 3.4M, 1.1Cr / 1.1B.
  static String compact(num value) {
    final v = value.abs();
    final sign = value < 0 ? '-' : '';
    String trim(double d) =>
        d >= 100 ? d.toStringAsFixed(0) : d.toStringAsFixed(1).replaceAll('.0', '');
    if (grouping == NumberGrouping.lakh) {
      if (v >= 10000000) return '$sign${trim(v / 10000000)}Cr';
      if (v >= 100000) return '$sign${trim(v / 100000)}L';
    } else {
      if (v >= 1000000000) return '$sign${trim(v / 1000000000)}B';
      if (v >= 1000000) return '$sign${trim(v / 1000000)}M';
    }
    if (v >= 1000) return '$sign${trim(v / 1000)}K';
    return '$sign${trim(v.toDouble())}';
  }

  static final _day = DateFormat('EEE, d MMM yyyy');
  static final _dayShort = DateFormat('d MMM yyyy');
  static final _time = DateFormat('hh:mm a');
  static final _formDate = DateFormat('dd-MMM-yyyy');
  static final _month = DateFormat('MMMM yyyy');
  static final _monthShort = DateFormat('MMM yy');
  static final _stamp = DateFormat('d MMM yyyy, hh:mm a');

  static String day(DateTime d) => _day.format(d);
  static String dayShort(DateTime d) => _dayShort.format(d);
  static String time(DateTime d) => _time.format(d);
  static String formDate(DateTime d) => _formDate.format(d);
  static String month(DateTime d) => _month.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);
  static String stamp(DateTime d) => _stamp.format(d);

  /// "Today", "Yesterday" or the full day.
  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return day(d);
  }
}
