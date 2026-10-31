import 'package:cash_flow/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(400, 800);
  const pagePadding = 16.0;

  /// A page too long for the screen, scrolled to its end. Returns how far
  /// the end of its content stops from the bottom of the screen.
  Future<double> gapBelowContent(WidgetTester tester, EdgeInsets system) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screen, padding: system, viewPadding: system),
          child: Scaffold(
            appBar: AppBar(title: const Text('Page')),
            body: const PageBody(
              children: [
                SizedBox(height: 2000),
                SizedBox(key: ValueKey('end'), height: 40),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    return screen.height - tester.getBottomLeft(find.byKey(const ValueKey('end'))).dy;
  }

  testWidgets('with 3-button navigation, the end of a page clears the bar', (tester) async {
    expect(await gapBelowContent(tester, const EdgeInsets.only(bottom: 48)), 48 + pagePadding);
  });

  testWidgets('with gesture navigation, only the small space it takes is left', (tester) async {
    expect(await gapBelowContent(tester, const EdgeInsets.only(bottom: 16)), 16 + pagePadding);
  });

  testWidgets('with no navigation bar, no space is added', (tester) async {
    expect(await gapBelowContent(tester, EdgeInsets.zero), pagePadding);
  });

  testWidgets('on its side, the bar at the edge is cleared too', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(right: 48, left: 24)),
          child: Builder(
            builder: (context) {
              final clear = const EdgeInsets.all(16).clearOfSystemBars(context);
              expect(clear, const EdgeInsets.fromLTRB(40, 16, 64, 16));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });
}
