import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task_item.dart';

void main() {
  test('TaskItem reads listName field', () {
    final task = TaskItem.fromJson({
      'id': 'task-1',
      'createdAt': DateTime(2026, 4, 21).toIso8601String(),
      'title': '测试任务',
      'description': '',
      'listName': '工作',
      'status': 'inbox',
    });

    expect(task.listName, '工作');
  });

  test('TaskItem defaults to inbox list when listName is missing', () {
    final task = TaskItem.fromJson({
      'id': 'task-2',
      'createdAt': DateTime(2026, 4, 21).toIso8601String(),
      'title': '默认清单任务',
      'description': '',
      'status': 'inbox',
    });

    expect(task.listName, '收集箱');
  });
}

