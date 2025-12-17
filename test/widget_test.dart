import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_guardian_app_project/main.dart';

void main() {
  testWidgets('GuardianApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GuardianApp(),
      ),
    );

    expect(find.byType(GuardianApp), findsOneWidget);
  });
}
