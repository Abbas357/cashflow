import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/analytics.dart';

/// Legend chip: a small swatch and a name. Charts never rely on colour
/// alone, so every two-series chart carries one.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// A round step (1, 2, 2.5 or 5 times a power of ten) that splits [span]
/// into about four gridlines.
double _niceStep(double span) {
  final raw = span <= 0 ? 2.5 : span / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * mag >= raw) return m * mag;
  }
  return 10 * mag;
}

/// Rounds [v] up (or down, when negative) to a whole number of [step]s.
double _snap(double v, double step) =>
    v >= 0 ? (v / step).ceil() * step : (v / step).floor() * step;

FlTitlesData _titles(
  BuildContext context, {
  required Widget Function(double, TitleMeta) bottom,
  required double interval,
}) {
  final style = Theme.of(context).textTheme.labelSmall;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: interval,
        getTitlesWidget: (v, meta) => (v / interval - (v / interval).round()).abs() > 0.001
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(Fmt.compact(v), style: style, textAlign: TextAlign.right),
              ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: bottom,
      ),
    ),
  );
}

FlGridData _grid(BuildContext context, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: context.cash.hairline, strokeWidth: 1),
);

Color _tooltipBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C3631)
        : const Color(0xFF212121);

/// Money in beside money out for each month. Paired thin bars, legend
/// above, value tooltip on hover or touch.
class InOutBarChart extends StatelessWidget {
  final List<Bucket> buckets;
  final double height;

  const InOutBarChart({super.key, required this.buckets, this.height = 240});

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final style = Theme.of(context).textTheme.labelSmall;
    final peak = buckets.fold<double>(0, (m, b) => math.max(m, math.max(b.cashIn, b.cashOut)));
    if (peak == 0) {
      return SizedBox(
        height: height * 0.5,
        child: Center(
          child: Text(
            'No entries in these months yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final interval = _niceStep(peak);
    final maxY = math.max(interval, _snap(peak, interval));
    final barWidth = buckets.length > 8 ? 7.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            LegendDot(color: c.inChart, label: 'Cash in'),
            LegendDot(color: c.outChart, label: 'Cash out'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: _grid(context, interval),
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: c.hairline)),
              ),
              titlesData: _titles(
                context,
                interval: interval,
                bottom: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                  final every = buckets.length > 8 ? 2 : 1;
                  if (i % every != 0 && i != buckets.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(buckets[i].label, style: style),
                  );
                },
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _tooltipBg(context),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${buckets[gi].label}\n',
                    const TextStyle(color: Colors.white70, fontSize: 11),
                    children: [
                      TextSpan(
                        text: '${ri == 0 ? 'In' : 'Out'}  ${Fmt.money(rod.toY)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i].cashIn,
                        color: c.inChart,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: buckets[i].cashOut,
                        color: c.outChart,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Balance at the end of each month: one line, so no legend.
class BalanceLineChart extends StatelessWidget {
  final List<Bucket> buckets;
  final double height;

  const BalanceLineChart({super.key, required this.buckets, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final primary = Theme.of(context).colorScheme.primary;
    final style = Theme.of(context).textTheme.labelSmall;
    final values = buckets.map((b) => b.closing).toList();
    final hi = values.fold<double>(0, math.max);
    final lo = values.fold<double>(0, math.min);
    final interval = _niceStep(hi - lo);
    final maxY = math.max(interval, _snap(hi, interval));
    final minY = lo >= 0 ? 0.0 : _snap(lo, interval);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: _grid(context, interval),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            context,
            interval: interval,
            bottom: (v, meta) {
              final i = v.toInt();
              if (v != i || i < 0 || i >= buckets.length) return const SizedBox.shrink();
              final every = buckets.length > 8 ? 2 : 1;
              if (i % every != 0 && i != buckets.length - 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(buckets[i].label, style: style),
              );
            },
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (minY < 0) HorizontalLine(y: 0, color: c.muted, strokeWidth: 1, dashArray: [4, 4]),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${buckets[s.x.toInt()].label}\n',
                    const TextStyle(color: Colors.white70, fontSize: 11),
                    children: [
                      TextSpan(
                        text: Fmt.money(s.y),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
              ],
              color: primary,
              barWidth: 2,
              isCurved: false,
              dotData: FlDotData(
                getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: primary,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single-series horizontal bar, drawn as a plain row so labels stay
/// readable at any width. Used for "where the money went".
class RankBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String trailing;
  final Color color;

  const RankBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Tooltip(
      message: '$label: ${Fmt.money(value)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: t.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  trailing,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (_, box) => Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.cash.hairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: math.max(4, box.maxWidth * frac),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
