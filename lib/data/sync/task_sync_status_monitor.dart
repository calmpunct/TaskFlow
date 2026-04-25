import 'dart:async';

import 'package:taskflow/data/local/app_database.dart';
import 'package:taskflow/data/sync/sync_engine.dart';

/// Monitors task status changes and tracks sync status
class TaskSyncStatusMonitor {
  TaskSyncStatusMonitor({
    required AppDatabase database,
    required SyncEngine syncEngine,
  })  : _db = database,
        _syncEngine = syncEngine;

  final AppDatabase _db;
  // ignore: unused_field
  final SyncEngine _syncEngine;
  final StreamController<TaskSyncStatus> _statusController =
      StreamController<TaskSyncStatus>.broadcast();

  // ignore: unused_field
  DateTime? _lastStatusChangeTime;
  // ignore: unused_field
  int _pendingStatusChanges = 0;

  /// Watch task sync status changes
  Stream<TaskSyncStatus> watchSyncStatus() => _statusController.stream;

  /// Get current sync status
  Future<TaskSyncStatus> getCurrentStatus() async {
    final pendingOps = await _db.opsDao.getPendingOps();
    final syncState = await _db.syncStateDao.ensureGlobalState();
    
    return TaskSyncStatus(
      hasPendingChanges: pendingOps.isNotEmpty,
      pendingChangesCount: pendingOps.length,
      lastSyncAt: syncState.lastSyncAt,
      isSyncing: syncState.isSyncing,
      lastError: syncState.lastError,
      lastStatusChangeAt: _lastStatusChangeTime,
    );
  }

  /// Track when a task status changes
  void notifyTaskStatusChanged(String taskId, String oldStatus, String newStatus) {
    _lastStatusChangeTime = DateTime.now();
    _pendingStatusChanges++;
    
    _updateStatus();
  }

  /// Notify that sync completed
  void notifySyncCompleted() {
    _pendingStatusChanges = 0;
    _updateStatus();
  }

  /// Notify that sync failed
  void notifySyncFailed(String error) {
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final status = await getCurrentStatus();
    _statusController.add(status);
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}

/// Represents the current sync status of tasks
class TaskSyncStatus {
  const TaskSyncStatus({
    required this.hasPendingChanges,
    required this.pendingChangesCount,
    required this.lastSyncAt,
    required this.isSyncing,
    required this.lastError,
    required this.lastStatusChangeAt,
  });

  /// Whether there are unsync'ed changes
  final bool hasPendingChanges;

  /// Count of pending changes
  final int pendingChangesCount;

  /// Last successful sync time
  final DateTime? lastSyncAt;

  /// Whether currently syncing
  final bool isSyncing;

  /// Last error message if any
  final String? lastError;

  /// Last time a task status changed
  final DateTime? lastStatusChangeAt;

  /// Whether sync is needed (has changes and not currently syncing)
  bool get needsSync => hasPendingChanges && !isSyncing;

  /// Human-readable status message
  String get statusMessage {
    if (isSyncing) {
      return '正在同步中...';
    }
    if (lastError != null && lastError!.isNotEmpty) {
      return '同步失败: $lastError';
    }
    if (hasPendingChanges) {
      return '有 $pendingChangesCount 项待同步更改';
    }
    if (lastSyncAt != null) {
      final diffMinutes = DateTime.now().difference(lastSyncAt!).inMinutes;
      if (diffMinutes < 1) {
        return '刚刚已同步';
      } else if (diffMinutes < 60) {
        return '最后同步于 $diffMinutes 分钟前';
      } else {
        final diffHours = (diffMinutes / 60).toStringAsFixed(0);
        return '最后同步于 $diffHours 小时前';
      }
    }
    return '未进行过同步';
  }
}

