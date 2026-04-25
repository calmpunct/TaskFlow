// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/main.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Bottom navigation renders and switches tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('整理今天的待办事项').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('任务'), findsWidgets);
    expect(find.text('专注'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('纪念日'), findsOneWidget);
    expect(find.text('添加任务'), findsOneWidget);

    await tester.tap(find.text('专注'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('专注 页面'), findsOneWidget);

    await tester.tap(find.text('日历'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('日历 页面'), findsOneWidget);

    await tester.tap(find.text('纪念日'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('添加纪念日'), findsOneWidget);
  });
}
