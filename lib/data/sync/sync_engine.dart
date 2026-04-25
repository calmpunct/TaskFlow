import 'dart:async';


abstract class SyncEngine {
  Stream<SyncProgress> watchProgress();

  Future<void> pushPendingOps();

  Future<void> pullRemoteOps();

  Future<void> resolveConflicts();

  Future<void> syncNow();
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
      SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop pull: network transport is not configured.',
      ),
    );
  }

  @override
  Future<void> pushPendingOps() async {
    _controller.add(
      SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop push: network transport is not configured.',
      ),
    );
  }

  @override
  Future<void> resolveConflicts() async {
    _controller.add(
      SyncProgress(
        isSyncing: false,
        lastMessage: 'Noop resolve: conflict policy is not configured.',
      ),
    );
  }

  @override
  Future<void> syncNow() async {
    _controller.add(const SyncProgress(isSyncing: true, lastMessage: 'Sync started'));
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

  Future<void> dispose() async {
    await _controller.close();
  }
}

