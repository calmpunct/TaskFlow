part of '../app_database.dart';

@DriftAccessor(tables: [SyncStates])
class SyncStateDao extends DatabaseAccessor<AppDatabase> with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<SyncState> ensureGlobalState() async {
    final existing = await (select(syncStates)
          ..where((s) => s.scope.equals('global')))
        .getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    await into(syncStates).insert(
      const SyncStatesCompanion(scope: Value('global')),
      mode: InsertMode.insertOrIgnore,
    );

    return (select(syncStates)..where((s) => s.scope.equals('global'))).getSingle();
  }

  Stream<SyncState?> watchGlobalState() {
    return (select(syncStates)..where((s) => s.scope.equals('global'))).watchSingleOrNull();
  }

  Future<void> updateGlobalState(SyncStatesCompanion entry) async {
    await ensureGlobalState();
    await (update(syncStates)..where((s) => s.scope.equals('global'))).write(entry);
  }
}

