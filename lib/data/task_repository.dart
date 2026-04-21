import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/models/task_item.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> loadTasks();

  Future<void> saveTasks(List<TaskItem> tasks);

  Future<List<String>> loadCustomLists();

  Future<void> saveCustomLists(List<String> lists);
}

class SharedPrefsTaskRepository implements TaskRepository {
  const SharedPrefsTaskRepository();

  static const String _storageKey = 'task_items_v2';
  static const String _listStorageKey = 'task_lists_v1';

  @override
  Future<List<TaskItem>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <TaskItem>[];
    }

    try {
      return TaskItem.decodeList(raw);
    } catch (_) {
      return <TaskItem>[];
    }
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, TaskItem.encodeList(tasks));
  }

  @override
  Future<List<String>> loadCustomLists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_listStorageKey) ?? <String>[];
  }

  @override
  Future<void> saveCustomLists(List<String> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_listStorageKey, lists);
  }
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({List<TaskItem>? initialTasks, List<String>? initialLists})
      : _tasks = List<TaskItem>.from(initialTasks ?? const <TaskItem>[]),
        _lists = List<String>.from(initialLists ?? const <String>[]);

  List<TaskItem> _tasks;
  List<String> _lists;

  @override
  Future<List<TaskItem>> loadTasks() async {
    return List<TaskItem>.from(_tasks);
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    _tasks = List<TaskItem>.from(tasks);
  }

  @override
  Future<List<String>> loadCustomLists() async {
    return List<String>.from(_lists);
  }

  @override
  Future<void> saveCustomLists(List<String> lists) async {
    _lists = List<String>.from(lists);
  }
}

