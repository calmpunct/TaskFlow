import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:taskflow/data/local/app_database.dart';
import 'package:taskflow/models/anniversary_item.dart';
import 'package:taskflow/models/task_item.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> loadTasks();

  Stream<List<TaskItem>> watchTasks();

  Future<void> saveTasks(List<TaskItem> tasks);

  Future<void> createTask(TaskItem task);

  Future<void> updateTask(TaskItem task);

  Future<void> deleteTask(String taskId);

  Future<List<String>> loadCustomLists();

  Future<void> saveCustomLists(List<String> lists);

  Future<List<AnniversaryItem>> loadAnniversaries();

  Future<void> saveAnniversaries(List<AnniversaryItem> anniversaries);
}

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository({AppDatabase? database, String? deviceId})
      : _db = database ?? AppDatabase.instance(),
        _deviceId = deviceId ?? _createDeviceId() {
    _bootstrapFuture = _bootstrap();
  }

  final AppDatabase _db;
  final String _deviceId;
  late final Future<void> _bootstrapFuture;

  static String _createDeviceId() {
    final random = Random();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'device-$stamp-$suffix';
  }

  Future<void> _bootstrap() async {
    final now = DateTime.now();
    await _db.deviceDao.upsertDevice(
      DevicesCompanion(
        deviceId: Value(_deviceId),
        platform: const Value('flutter'),
        installedAt: Value(now),
        lastSeenAt: Value(now),
        isCurrent: const Value(true),
      ),
    );
    await _db.deviceDao.setCurrentDevice(_deviceId);
    await _db.syncStateDao.ensureGlobalState();
  }

  Future<void> _appendOp({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
    int? baseVersion,
  }) async {
    await _db.opsDao.insertIdempotent(
      OpsCompanion(
        opId: Value('op-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 24)}'),
        entityType: Value(entityType),
        entityId: Value(entityId),
        action: Value(action),
        payload: Value(jsonEncode(payload)),
        baseVersion: Value(baseVersion),
        deviceId: Value(_deviceId),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  TasksCompanion _toTaskCompanion(TaskItem task, {required int version}) {
    final now = DateTime.now();
    return TasksCompanion(
      id: Value(task.id),
      title: Value(task.title),
      description: Value(task.description),
      listName: Value(task.listName),
      dueAt: Value(task.dueAt),
      status: Value(task.status.name),
      version: Value(version),
      createdAt: Value(task.createdAt),
      updatedAt: Value(now),
      isDeleted: Value(task.status == TaskStatus.trashed),
      deletedAt: Value(task.status == TaskStatus.trashed ? now : null),
      lastDeviceId: Value(_deviceId),
    );
  }

  TaskItem _toTaskModel(Task row) {
    return TaskItem(
      id: row.id,
      title: row.title,
      description: row.description,
      listName: row.listName,
      dueAt: row.dueAt,
      status: TaskStatus.values.firstWhere(
        (value) => value.name == row.status,
        orElse: () => TaskStatus.inbox,
      ),
      createdAt: row.createdAt,
    );
  }

  AnniversariesCompanion _toAnniversaryCompanion(AnniversaryItem item) {
    return AnniversariesCompanion(
      id: Value(item.id),
      name: Value(item.name),
      date: Value(item.date),
      createdAt: Value(item.createdAt),
      note: Value(item.note),
      isPinned: Value(item.isPinned),
      isBirthday: Value(item.isBirthday),
      remindersJson: Value(jsonEncode(item.reminders.map((r) => r.name).toList())),
      iconType: Value(item.iconType.name),
      iconCodePoint: Value(item.iconCodePoint),
      iconFontFamily: Value(item.iconFontFamily),
      imagePath: Value(item.imagePath),
    );
  }

  AnniversaryItem _toAnniversaryModel(Anniversary row) {
    final decoded = (jsonDecode(row.remindersJson) as List<dynamic>)
        .map((value) => ReminderOption.values.firstWhere(
              (option) => option.name == value,
              orElse: () => ReminderOption.none,
            ))
        .toSet()
        .toList();

    return AnniversaryItem(
      id: row.id,
      name: row.name,
      date: row.date,
      createdAt: row.createdAt,
      note: row.note,
      isPinned: row.isPinned,
      isBirthday: row.isBirthday,
      reminders: decoded.isEmpty ? const [ReminderOption.none] : decoded,
      iconType: AnniversaryIconType.values.firstWhere(
        (value) => value.name == row.iconType,
        orElse: () => AnniversaryIconType.builtIn,
      ),
      iconCodePoint: row.iconCodePoint,
      iconFontFamily: row.iconFontFamily,
      imagePath: row.imagePath,
    );
  }

  @override
  Future<List<TaskItem>> loadTasks() async {
    await _bootstrapFuture;
    final rows = await _db.taskDao.getAllTasks();
    return rows.map(_toTaskModel).toList();
  }

  @override
  Stream<List<TaskItem>> watchTasks() {
    return _db.taskDao.watchAllTasks().map(
          (rows) => rows.map(_toTaskModel).toList(),
        );
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    await _bootstrapFuture;
    final entries = tasks
        .map((task) => _toTaskCompanion(task, version: 1))
        .toList();
    await _db.taskDao.replaceAll(entries);
    await _appendOp(
      entityType: 'tasks',
      entityId: 'snapshot',
      action: 'replace_snapshot',
      payload: <String, dynamic>{'count': tasks.length},
    );
  }

  @override
  Future<void> createTask(TaskItem task) async {
    await _bootstrapFuture;
    await _db.taskDao.upsertTask(_toTaskCompanion(task, version: 1));
    await _appendOp(
      entityType: 'task',
      entityId: task.id,
      action: 'create',
      payload: task.toJson(),
      baseVersion: 1,
    );
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    await _bootstrapFuture;
    final current = await _db.taskDao.findById(task.id);
    final nextVersion = (current?.version ?? 0) + 1;
    await _db.taskDao.upsertTask(_toTaskCompanion(task, version: nextVersion));
    await _appendOp(
      entityType: 'task',
      entityId: task.id,
      action: 'update',
      payload: task.toJson(),
      baseVersion: nextVersion,
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _bootstrapFuture;
    await _db.taskDao.deleteById(taskId);
    await _appendOp(
      entityType: 'task',
      entityId: taskId,
      action: 'delete',
      payload: <String, dynamic>{'id': taskId},
    );
  }

  @override
  Future<List<String>> loadCustomLists() async {
    await _bootstrapFuture;
    return _db.customListDao.getAllNames();
  }

  @override
  Future<void> saveCustomLists(List<String> lists) async {
    await _bootstrapFuture;
    await _db.customListDao.replaceAll(lists);
    await _appendOp(
      entityType: 'custom_lists',
      entityId: 'snapshot',
      action: 'replace_snapshot',
      payload: <String, dynamic>{'count': lists.length},
    );
  }

  @override
  Future<List<AnniversaryItem>> loadAnniversaries() async {
    await _bootstrapFuture;
    final rows = await _db.anniversaryDao.getAllAnniversaries();
    return rows.map(_toAnniversaryModel).toList();
  }

  @override
  Future<void> saveAnniversaries(List<AnniversaryItem> anniversaries) async {
    await _bootstrapFuture;
    final entries = anniversaries.map(_toAnniversaryCompanion).toList();
    await _db.anniversaryDao.replaceAll(entries);
    await _appendOp(
      entityType: 'anniversaries',
      entityId: 'snapshot',
      action: 'replace_snapshot',
      payload: <String, dynamic>{'count': anniversaries.length},
    );
  }
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({List<TaskItem>? initialTasks, List<String>? initialLists})
      : _tasks = List<TaskItem>.from(initialTasks ?? const <TaskItem>[]),
        _lists = List<String>.from(initialLists ?? const <String>[]);

  List<TaskItem> _tasks;
  List<String> _lists;
  List<AnniversaryItem> _anniversaries = <AnniversaryItem>[];
  final StreamController<List<TaskItem>> _taskController =
      StreamController<List<TaskItem>>.broadcast();

  void _emitTasks() {
    _taskController.add(List<TaskItem>.from(_tasks));
  }

  @override
  Future<List<TaskItem>> loadTasks() async {
    return List<TaskItem>.from(_tasks);
  }

  @override
  Stream<List<TaskItem>> watchTasks() async* {
    yield List<TaskItem>.from(_tasks);
    yield* _taskController.stream;
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    _tasks = List<TaskItem>.from(tasks);
    _emitTasks();
  }

  @override
  Future<void> createTask(TaskItem task) async {
    _tasks = <TaskItem>[task, ..._tasks];
    _emitTasks();
  }

  @override
  Future<void> updateTask(TaskItem task) async {
    _tasks = _tasks.map((item) => item.id == task.id ? task : item).toList();
    _emitTasks();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks = _tasks.where((item) => item.id != taskId).toList();
    _emitTasks();
  }

  @override
  Future<List<String>> loadCustomLists() async {
    return List<String>.from(_lists);
  }

  @override
  Future<void> saveCustomLists(List<String> lists) async {
    _lists = List<String>.from(lists);
  }

  @override
  Future<List<AnniversaryItem>> loadAnniversaries() async {
    return List<AnniversaryItem>.from(_anniversaries);
  }

  @override
  Future<void> saveAnniversaries(List<AnniversaryItem> anniversaries) async {
    _anniversaries = List<AnniversaryItem>.from(anniversaries);
  }
}
