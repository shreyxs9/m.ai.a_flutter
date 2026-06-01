import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_flutter/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated startup renders login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MaiaApp()));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Continue with Google').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('M.AI.A'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
