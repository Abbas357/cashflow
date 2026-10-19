import 'package:cash_flow/core/theme/app_theme.dart';
import 'package:cash_flow/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the empty message fits a short space (phone on its side, keyboard up)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            // The space the ledger had on the phone when it overflowed.
            child: SizedBox(
              width: 384,
              height: 97.6,
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No entries here yet',
                message: 'Tap Cash In or Cash Out below to record your first entry.',
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No entries here yet'), findsOneWidget);
  });
}
