import 'package:cash_flow/boot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the icon and progress bar straight away', (tester) async {
    await tester.pumpWidget(const BootApp());
    expect(find.bySemanticsLabel('Loading Cash Flow'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // Let startup run out (it fails here, see below) so no timers dangle.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    tester.takeException();
  });

  testWidgets('has no Navigator, so it cannot overwrite the web address', (tester) async {
    // A Navigator reports `/` to the browser on its first frame, replacing
    // the address the app was opened at (/insights, /account/<uuid>, ...)
    // before the real app's router reads it.
    await tester.pumpWidget(const BootApp());
    expect(find.byType(Navigator), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('Cash Flow could not start'), findsOneWidget);
    expect(find.byType(Navigator), findsNothing);
  });

  testWidgets('a failing step shows the error and Try again, not an endless logo', (tester) async {
    // Tests have no device storage, so opening the database fails: exactly
    // the kind of failure that used to leave the app on its launch logo.
    await tester.pumpWidget(const BootApp());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    // Reported to the log as well; not a test failure.
    tester.takeException();

    expect(find.text('Cash Flow could not start'), findsOneWidget);
    expect(find.text('Something went wrong while opening your books.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Copy details'), findsOneWidget);

    // Try again runs startup once more, and fails the same way here.
    await tester.tap(find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('Cash Flow could not start'), findsOneWidget);
  });
}
