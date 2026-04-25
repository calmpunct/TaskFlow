import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taskflow/data/local/app_database.dart';
import 'package:taskflow/data/sync/s3_object_storage_client.dart';
import 'package:taskflow/data/sync/sync_config_repository.dart';
import 'package:taskflow/data/sync/sync_storage_config.dart';

abstract class SyncEngine {
  Stream<SyncProgress> watchProgress();

  Future<void> pushPendingOps();

  Future<void> pullRemoteOps();

  Future<void> resolveConflicts();

  Future<void> syncNow();

  Future<void> testConnection(SyncStorageConfig config);
}

class SyncProgress {
  const SyncProgress({
    required this.isSyncing,
    this.lastMessage,
    this.lastSyncAt,
  });

  final bool isSyncing;
  final String? lastMessage;
  final DateTime? lastSyncAt;
}

class NoopSyncEngine implements SyncEngine {
  final StreamController<SyncProgress> _controller =
      StreamController<SyncProgress>.broadcast();

  @override
  Stream<SyncProgress> watchProgress() => _controller.stream;

  @override
  Future<void> pullRemoteOps() async {
    _controller.add(
      const SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop pull: network transport is not configured.',
      ),
    );
  }

  @override
  Future<void> pushPendingOps() async {
    _controller.add(
      const SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop push: network transport is not configured.',
      ),
    );
  }

  @override
  Future<void> resolveConflicts() async {
    _controller.add(
      const SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop resolve: conflict policy is not configured.',
      ),
    );
  }

  @override
  Future<void> syncNow() async {
    _controller.add(
      const SyncProgress(isSyncing: true, lastMessage: 'Sync started'),
    );
    await pushPendingOps();
    await pullRemoteOps();
    await resolveConflicts();
    _controller.add(
      SyncProgress(
        isSyncing: false,
        lastMessage: 'Sync finished (noop).',
        lastSyncAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> testConnection(SyncStorageConfig config) async {
    if (!config.isComplete) {
      throw Exception('请先填写完整的对象存储配置。');
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class S3SyncEngine implements SyncEngine {
  S3SyncEngine({
    required AppDatabase database,
    required SyncConfigRepository configRepository,
  }) : _db = database,
       _configRepository = configRepository;

  static const String _snapshotKey = 'snapshot.json';

  final AppDatabase _db;
  final SyncConfigRepository _configRepository;
  final StreamController<SyncProgress> _controller =
      StreamController<SyncProgress>.broadcast();

  SyncStorageConfig? _activeConfig;
  S3ObjectStorageClient? _client;

  @override
  Stream<SyncProgress> watchProgress() => _controller.stream;

  @override
  Future<void> testConnection(SyncStorageConfig config) async {
    if (!config.isComplete) {
      throw Exception('请先填写完整的对象存储配置。');
    }
    await S3ObjectStorageClient(config).testConnection();
  }

  @override
  Future<void> pushPendingOps() async {
    final client = await _requireClient();
    final pendingOps = await _db.opsDao.getPendingOps();
    if (pendingOps.isEmpty) {
      _controller.add(
        const SyncProgress(isSyncing: true, lastMessage: '没有需要上传的本地变更。'),
      );
      return;
    }

    final localSnapshot = await _exportLocalSnapshot();
    final remoteRaw = await client.getText(_snapshotKey);
    final remoteSnapshot = _decodeSnapshot(remoteRaw);
    final merged = _mergeSnapshots(
      remote: remoteSnapshot,
      local: localSnapshot,
      preferLocal: true,
    );

    final nextRevision = (remoteSnapshot?['revision'] as int? ?? 0) + 1;
    final uploadPayload = <String, dynamic>{
      'revision': nextRevision,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      ...merged,
    };

    await client.putText(_snapshotKey, jsonEncode(uploadPayload));
    await _db.transaction(() async {
      for (final op in pendingOps) {
        await _db.opsDao.markSynced(op.opId);
      }
      await _db.syncStateDao.updateGlobalState(
        SyncStatesCompanion(
          syncCursor: Value(nextRevision.toString()),
          lastPushedOpAt: Value(DateTime.now()),
        ),
      );
    });
    _controller.add(
      SyncProgress(
        isSyncing: true,
        lastMessage: '已上传 ${pendingOps.length} 条本地变更。',
      ),
    );
  }

  @override
  Future<void> pullRemoteOps() async {
    final client = await _requireClient();
    final remoteRaw = await client.getText(_snapshotKey);
    if (remoteRaw == null || remoteRaw.trim().isEmpty) {
      _controller.add(
        const SyncProgress(isSyncing: true, lastMessage: '远端目录中暂无同步数据。'),
      );
      return;
    }

    final remoteSnapshot = _decodeSnapshot(remoteRaw);
    if (remoteSnapshot == null) {
      return;
    }

    final remoteRevision = remoteSnapshot['revision'] as int? ?? 0;
    final state = await _db.syncStateDao.ensureGlobalState();
    final localRevision = int.tryParse(state.syncCursor ?? '0') ?? 0;

    if (remoteRevision <= localRevision) {
      _controller.add(
        const SyncProgress(isSyncing: true, lastMessage: '远端无新数据。'),
      );
      return;
    }

    await _applySnapshot(remoteSnapshot);
    await _db.syncStateDao.updateGlobalState(
      SyncStatesCompanion(
        syncCursor: Value(remoteRevision.toString()),
        lastPulledOpAt: Value(DateTime.now()),
      ),
    );
    _controller.add(
      SyncProgress(isSyncing: true, lastMessage: '已拉取远端版本 $remoteRevision。'),
    );
  }

  @override
  Future<void> resolveConflicts() async {
    _controller.add(
      const SyncProgress(isSyncing: true, lastMessage: '冲突策略: 以最新同步快照为准。'),
    );
  }

  @override
  Future<void> syncNow() async {
    try {
      _controller.add(
        const SyncProgress(isSyncing: true, lastMessage: '开始同步...'),
      );
      final config = await _configRepository.load();
      if (!config.enabled) {
        _controller.add(
          const SyncProgress(isSyncing: false, lastMessage: '未启用对象存储同步。'),
        );
        return;
      }
      if (!config.isComplete) {
        _controller.add(
          const SyncProgress(isSyncing: false, lastMessage: '同步配置不完整，已跳过。'),
        );
        return;
      }

      _activeConfig = config;
      _client = S3ObjectStorageClient(config);
      await pushPendingOps();
      await pullRemoteOps();
      await resolveConflicts();
      await _db.syncStateDao.updateGlobalState(
        SyncStatesCompanion(
          isSyncing: const Value(false),
          lastSyncAt: Value(DateTime.now()),
          lastError: const Value(null),
        ),
      );
      _controller.add(
        SyncProgress(
          isSyncing: false,
          lastMessage: '同步完成。',
          lastSyncAt: DateTime.now(),
        ),
      );
    } catch (error) {
      await _db.syncStateDao.updateGlobalState(
        SyncStatesCompanion(
          isSyncing: const Value(false),
          lastError: Value(error.toString()),
        ),
      );
      _controller.add(
        SyncProgress(isSyncing: false, lastMessage: '同步失败: $error'),
      );
      rethrow;
    }
  }

  Future<S3ObjectStorageClient> _requireClient() async {
    if (_client != null) {
      return _client!;
    }
    final config = _activeConfig ?? await _configRepository.load();
    if (!config.enabled || !config.isComplete) {
      throw Exception('未启用或未完成对象存储配置。');
    }
    _activeConfig = config;
    _client = S3ObjectStorageClient(config);
    return _client!;
  }

  Future<Map<String, dynamic>> _exportLocalSnapshot() async {
    final tasks = await _db.taskDao.getAllTasks();
    final lists = await _db.customListDao.getAllNames();
    final anniversaries = await _db.anniversaryDao.getAllAnniversaries();

    return <String, dynamic>{
      'tasks': tasks.map((task) => _taskToMap(task)).toList(),
      'customLists': lists,
      'anniversaries': anniversaries
          .map((item) => _anniversaryToMap(item))
          .toList(),
    };
  }

  Map<String, dynamic>? _decodeSnapshot(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Map<String, dynamic> _mergeSnapshots({
    required Map<String, dynamic>? remote,
    required Map<String, dynamic> local,
    required bool preferLocal,
  }) {
    final remoteTasks = _mapById(
      (remote?['tasks'] as List<dynamic>? ?? const <dynamic>[]),
    );
    final localTasks = _mapById(
      (local['tasks'] as List<dynamic>? ?? const <dynamic>[]),
    );
    final remoteAnn = _mapById(
      (remote?['anniversaries'] as List<dynamic>? ?? const <dynamic>[]),
    );
    final localAnn = _mapById(
      (local['anniversaries'] as List<dynamic>? ?? const <dynamic>[]),
    );

    final mergedTasks = <String, Map<String, dynamic>>{
      ...remoteTasks,
      if (preferLocal) ...localTasks,
      if (!preferLocal) ...localTasks,
    };
    final mergedAnn = <String, Map<String, dynamic>>{
      ...remoteAnn,
      if (preferLocal) ...localAnn,
      if (!preferLocal) ...localAnn,
    };

    final mergedLists = <String>{
      ...((remote?['customLists'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()),
      ...((local['customLists'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()),
    }.toList()..sort();

    return <String, dynamic>{
      'tasks': mergedTasks.values.toList(),
      'customLists': mergedLists,
      'anniversaries': mergedAnn.values.toList(),
    };
  }

  Map<String, Map<String, dynamic>> _mapById(List<dynamic> source) {
    final mapped = <String, Map<String, dynamic>>{};
    for (final row in source) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final id = row['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }
      mapped[id] = row;
    }
    return mapped;
  }

  Future<void> _applySnapshot(Map<String, dynamic> snapshot) async {
    final taskEntries =
        (snapshot['tasks'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_taskFromMap)
            .toList();

    final anniversaryEntries =
        (snapshot['anniversaries'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_anniversaryFromMap)
            .toList();

    final customLists =
        (snapshot['customLists'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList();

    await _db.transaction(() async {
      await _db.taskDao.replaceAll(taskEntries);
      await _db.customListDao.replaceAll(customLists);
      await _db.anniversaryDao.replaceAll(anniversaryEntries);
    });
  }

  Map<String, dynamic> _taskToMap(Task row) {
    return <String, dynamic>{
      'id': row.id,
      'title': row.title,
      'description': row.description,
      'listName': row.listName,
      'dueAt': row.dueAt?.toIso8601String(),
      'status': row.status,
      'version': row.version,
      'isDeleted': row.isDeleted,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'deletedAt': row.deletedAt?.toIso8601String(),
      'lastDeviceId': row.lastDeviceId,
    };
  }

  TasksCompanion _taskFromMap(Map<String, dynamic> row) {
    DateTime? parseDate(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return TasksCompanion(
      id: Value(row['id'] as String),
      title: Value(row['title'] as String? ?? ''),
      description: Value(row['description'] as String? ?? ''),
      listName: Value(row['listName'] as String? ?? '收集箱'),
      dueAt: Value(parseDate('dueAt')),
      status: Value(row['status'] as String? ?? 'inbox'),
      version: Value(row['version'] as int? ?? 1),
      isDeleted: Value(row['isDeleted'] as bool? ?? false),
      createdAt: Value(parseDate('createdAt') ?? DateTime.now()),
      updatedAt: Value(parseDate('updatedAt') ?? DateTime.now()),
      deletedAt: Value(parseDate('deletedAt')),
      lastDeviceId: Value(row['lastDeviceId'] as String?),
    );
  }

  Map<String, dynamic> _anniversaryToMap(Anniversary row) {
    return <String, dynamic>{
      'id': row.id,
      'name': row.name,
      'date': row.date.toIso8601String(),
      'createdAt': row.createdAt.toIso8601String(),
      'note': row.note,
      'isPinned': row.isPinned,
      'isBirthday': row.isBirthday,
      'remindersJson': row.remindersJson,
      'iconType': row.iconType,
      'iconCodePoint': row.iconCodePoint,
      'iconFontFamily': row.iconFontFamily,
      'imagePath': row.imagePath,
    };
  }

  AnniversariesCompanion _anniversaryFromMap(Map<String, dynamic> row) {
    DateTime parseDate(String key) {
      final raw = row[key] as String?;
      final parsed = raw == null ? null : DateTime.tryParse(raw);
      return parsed ?? DateTime.now();
    }

    return AnniversariesCompanion(
      id: Value(row['id'] as String),
      name: Value(row['name'] as String? ?? ''),
      date: Value(parseDate('date')),
      createdAt: Value(parseDate('createdAt')),
      note: Value(row['note'] as String? ?? ''),
      isPinned: Value(row['isPinned'] as bool? ?? false),
      isBirthday: Value(row['isBirthday'] as bool? ?? false),
      remindersJson: Value(row['remindersJson'] as String? ?? '[]'),
      iconType: Value(row['iconType'] as String? ?? 'builtIn'),
      iconCodePoint: Value(row['iconCodePoint'] as int?),
      iconFontFamily: Value(row['iconFontFamily'] as String?),
      imagePath: Value(row['imagePath'] as String?),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
