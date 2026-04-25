/// Utility functions for sync operations and task status tracking
class SyncUtils {
  /// Compares two task maps and returns a summary of changes
  static SyncDiff compareTaskSnapshots(
    Map<String, dynamic>? remote,
    Map<String, dynamic>? local,
  ) {
    final remoteCount = (remote?['tasks'] as List<dynamic>? ?? []).length;
    final localCount = (local?['tasks'] as List<dynamic>? ?? []).length;

    final remoteRevision = remote?['revision'] as int? ?? 0;
    final localRevision = local?['revision'] as int? ?? 0;

    return SyncDiff(
      remoteTaskCount: remoteCount,
      localTaskCount: localCount,
      remoteRevision: remoteRevision,
      localRevision: localRevision,
      isLocalAhead: localRevision > remoteRevision,
      hasRemoteUpdates: remoteRevision > localRevision,
    );
  }

  /// Tracks status changes in a task
  static TaskStatusChange? detectStatusChange(
    Map<String, dynamic>? oldTask,
    Map<String, dynamic>? newTask,
  ) {
    if (oldTask == null || newTask == null) return null;

    final oldStatus = oldTask['status'] as String?;
    final newStatus = newTask['status'] as String?;
    final taskId = newTask['id'] as String?;

    if (oldStatus == null || newStatus == null || taskId == null || oldStatus == newStatus) {
      return null;
    }

    return TaskStatusChange(
      taskId: taskId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedAt: DateTime.now(),
    );
  }

  /// Validates task data for sync
  static bool isValidTaskForSync(Map<String, dynamic> task) {
    return task['id'] is String &&
        (task['id'] as String).isNotEmpty &&
        task['title'] is String &&
        task['createdAt'] is String;
  }

  /// Merges overdue/countdown information from local to remote
  static Map<String, dynamic> enrichTaskWithCountdownData(
    Map<String, dynamic> task,
  ) {
    if (task['dueAt'] == null) {
      return task;
    }

    try {
      final dueAt = DateTime.parse(task['dueAt'] as String);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);

      final countdownDays = dueDate.difference(today).inDays;

      return <String, dynamic>{
        ...task,
        '_countdownDays': countdownDays,
        '_isOverdue': countdownDays < 0 && task['status'] == 'inbox',
      };
    } catch (e) {
      return task;
    }
  }
}

/// Represents differences between remote and local sync snapshots
class SyncDiff {
  const SyncDiff({
    required this.remoteTaskCount,
    required this.localTaskCount,
    required this.remoteRevision,
    required this.localRevision,
    required this.isLocalAhead,
    required this.hasRemoteUpdates,
  });

  final int remoteTaskCount;
  final int localTaskCount;
  final int remoteRevision;
  final int localRevision;
  final bool isLocalAhead;
  final bool hasRemoteUpdates;

  String get summary {
    if (hasRemoteUpdates) {
      return '远端版本 $remoteRevision (任务 $remoteTaskCount 条)，本地需要更新';
    } else if (isLocalAhead) {
      return '本地版本 $localRevision (任务 $localTaskCount 条)，已超前远端';
    } else {
      return '已同步到最新版本 $localRevision (任务 $localTaskCount 条)';
    }
  }
}

/// Represents a task status change event
class TaskStatusChange {
  const TaskStatusChange({
    required this.taskId,
    required this.oldStatus,
    required this.newStatus,
    required this.changedAt,
  });

  final String taskId;
  final String oldStatus;
  final String newStatus;
  final DateTime changedAt;

  @override
  String toString() =>
      'TaskStatusChange(id: $taskId, $oldStatus → $newStatus at $changedAt)';
}

