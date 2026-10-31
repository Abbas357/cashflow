import 'package:cash_flow/services/cloud_sync.dart';
import 'package:cash_flow/ui/widgets/google_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Cloud extends ChangeNotifier implements CloudSync {
  @override
  bool signingIn = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_Cloud> pump(WidgetTester tester, void Function() onPressed) async {
    final cloud = _Cloud();
    await tester.pumpWidget(
      ChangeNotifierProvider<CloudSync?>.value(
        value: cloud,
        child: MaterialApp(home: Scaffold(body: GoogleButton(onPressed: onPressed))),
      ),
    );
    return cloud;
  }

  testWidgets('the text becomes a spinner while signing in, and comes back', (tester) async {
    final cloud = await pump(tester, () {});
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    cloud
      ..signingIn = true
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byType(GoogleLogo), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cloud
      ..signingIn = false
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('it can still be tapped while signing in, to bring the window back', (tester) async {
    var taps = 0;
    final cloud = await pump(tester, () => taps++);
    cloud
      ..signingIn = true
      ..notifyListeners();
    await tester.pump();

    await tester.tap(find.byType(OutlinedButton));
    expect(taps, 1);
  });
}
