import 'package:flutter_test/flutter_test.dart';
import 'package:vilka_ai_assist/app.dart';
import 'package:vilka_ai_assist/core/constants/app_constants.dart';

void main() {
  testWidgets('shell shows the app name', (WidgetTester tester) async {
    await tester.pumpWidget(const VilkaApp());

    expect(find.text(AppConstants.appName), findsOneWidget);
  });
}
