import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/models/task_item.dart';
import 'package:taskflow/pages/task_page.dart';

void main() {
  testWidgets('Task page shows drawer categories and filters tasks', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final repository = InMemoryTaskRepository(
      initialTasks: [
        TaskItem(
          id: '1',
          title: '整理今天的待办事项',
          createdAt: now,
          status: TaskStatus.inbox,
          dueAt: now,
        ),
        TaskItem(
          id: '2',
          title: '已完成任务',
          createdAt: now,
          status: TaskStatus.completed,
        ),
        TaskItem(
          id: '3',
          title: '项目周报',
          createdAt: now,
          status: TaskStatus.inbox,
          listName: '工作',
        ),
      ],
      initialLists: const ['工作'],
    );

    await tester.pumpWidget(MaterialApp(home: TaskPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('整理今天的待办事项'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('明天'), findsOneWidget);
    expect(find.text('最近7天'), findsOneWidget);
    expect(find.text('收集箱'), findsWidgets);
    expect(find.text('已经完成'), findsOneWidget);
    expect(find.text('垃圾桶'), findsOneWidget);
    expect(find.text('已经放弃'), findsOneWidget);
    expect(find.text('我的清单'), findsOneWidget);
    expect(find.text('工作', skipOffstage: false), findsOneWidget);
    expect(find.text('创建清单', skipOffstage: false), findsOneWidget);

    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.text('工作'),
      120,
      scrollable: drawerScrollable,
    );
    await tester.tap(find.text('工作', skipOffstage: false).last);
    await tester.pumpAndSettle();
    expect(find.text('项目周报'), findsOneWidget);
    expect(find.text('整理今天的待办事项'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已经完成'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('整理今天的待办事项'), findsNothing);
  });
}

