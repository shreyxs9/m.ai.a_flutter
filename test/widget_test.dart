import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_flutter/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated startup renders login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MaiaApp()));
    await tester.pumpAndSettle();

    expect(find.text('M.AI.A'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
