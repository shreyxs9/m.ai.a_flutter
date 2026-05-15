import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_flutter/app.dart';

void main() {
  testWidgets('renders the projects route', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaiaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Dashboard foundation route.'), findsOneWidget);
  });
}
