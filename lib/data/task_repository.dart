import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/task_item.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> loadTasks();

  Future<void> saveTasks(List<TaskItem> tasks);

  Future<List<String>> loadCustomLists();

  Future<void> saveCustomLists(List<String> lists);
}

class HiveTaskRepository implements TaskRepository {
  HiveTaskRepository._();

  factory HiveTaskRepository() => _instance;

  static const String _boxName = 'taskflow_storage_v1';
  static const String _storageKey = 'task_items';
  static const String _listStorageKey = 'task_lists';
  static final HiveTaskRepository _instance = HiveTaskRepository._();
  Future<Box<dynamic>>? _openBoxFuture;

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    _openBoxFuture ??= Hive.openBox<dynamic>(_boxName).catchError((Object error) {
      _openBoxFuture = null;
      throw error;
    });
    return _openBoxFuture!;
  }

  @override
  Future<List<TaskItem>> loadTasks() async {
    final box = await _openBox();
    final raw = box.get(_storageKey) as String?;
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
    final box = await _openBox();
    await box.put(_storageKey, TaskItem.encodeList(tasks));
  }

  @override
  Future<List<String>> loadCustomLists() async {
    final box = await _openBox();
    final raw = box.get(_listStorageKey);
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return <String>[];
  }

  @override
  Future<void> saveCustomLists(List<String> lists) async {
    final box = await _openBox();
    await box.put(_listStorageKey, lists);
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
