import 'package:intl/intl.dart';

/// How large numbers are grouped and which mark separates decimals.
enum NumberGrouping {
  /// South Asia: 4,78,940.50
  lakh('4,78,940.50', 'en_IN'),

  /// Most English-speaking countries, China, Japan: 478,940.50
  million('478,940.50', 'en_US'),

  /// Much of Europe and Latin America: 478.940,50
  dotComma('478.940,50', 'de'),

  /// France, the Nordics, Eastern Europe: 478 940,50
  spaceComma('478 940,50', 'fr'),

  /// Switzerland: 478'940.50
  apostrophe("478'940.50", 'de_CH');

  final String example;
  final String _locale;
  const NumberGrouping(this.example, this._locale);
}

/// Turns amounts and dates into text, following the user's settings.
class Fmt {
  Fmt._();

  static String currency = '';
  static NumberGrouping grouping = NumberGrouping.lakh;
  static int decimals = 0;

  static NumberFormat get _number {
    final fraction = decimals == 0 ? '' : '.${'0' * decimals}';
    final optional = decimals == 0 ? '.##' : '';
    final pattern = grouping == NumberGrouping.lakh ? '#,##,##0' : '#,##0';
    return NumberFormat('$pattern$fraction$optional', grouping._locale);
  }

  /// 4,78,940 or 478.940,50 (no currency symbol), as grouping says.
  /// French grouping uses a narrow space some fonts lack; a plain
  /// no-break space looks the same and prints everywhere.
  static String number(num value) => _number.format(value).replaceAll(' ', ' ');

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
