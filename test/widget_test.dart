import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_flutter/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated startup renders landing login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MaiaApp()));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Alignment, on autopilot').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('M.AI.A'), findsOneWidget);
    expect(find.text('Alignment, on autopilot'), findsOneWidget);
    expect(find.text('Async check-ins + daily digest'), findsOneWidget);
    expect(find.text('Real product surfaces'), findsOneWidget);
    expect(find.text('Three steps. Then it runs without you.'), findsOneWidget);
    expect(find.text("Get started - it's free"), findsOneWidget);
    expect(find.text('Cross-functional examples'), findsOneWidget);
    expect(
      find.text('More than a check-in. A whole calm workflow.'),
      findsOneWidget,
    );
  });
}
