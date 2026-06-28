import 'package:flutter_test/flutter_test.dart';

import 'package:ai_sizheng/main.dart';

void main() {
  testWidgets('app starts at login page', (WidgetTester tester) async {
    await tester.pumpWidget(const AiSizhengApp());

    await tester.pump();
    expect(find.text('AI思政打卡'), findsOneWidget);
    expect(find.text('学号/工号'), findsOneWidget);
  });
}
