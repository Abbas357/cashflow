import 'package:flutter/widgets.dart';

/// Width breakpoints shared by every screen.
class Breakpoints {
  Breakpoints._();

  /// Below this the app is a phone: modal drawer, single column.
  static const double tablet = 760;

  /// At and above this the navigation sits beside the ledger.
  static const double desktop = 1080;

  /// At and above this a summary panel joins on the right.
  static const double wide = 1400;
}

extension ResponsiveX on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  bool get isPhone => width < Breakpoints.tablet;
  bool get isDesktop => width >= Breakpoints.desktop;
  bool get isWide => width >= Breakpoints.wide;
}

/// Centres [child] and caps its width, so forms and reports do not stretch
/// across a desktop monitor.
class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidth({super.key, this.maxWidth = 760, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
