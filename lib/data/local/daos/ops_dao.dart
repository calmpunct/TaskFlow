part of '../app_database.dart';

@DriftAccessor(tables: [Ops])
class OpsDao extends DatabaseAccessor<AppDatabase> with _$OpsDaoMixin {
  OpsDao(super.db);

  Future<void> insertIdempotent(OpsCompanion entry) async {
    await into(ops).insert(
      entry,
      onConflict: DoNothing(target: [ops.opId]),
    );
  }

  Future<List<Op>> replayByEntity(String entityTypeValue, String entityIdValue) {
    final query = select(ops)
      ..where(
        (o) =>
            o.entityType.equals(entityTypeValue) & o.entityId.equals(entityIdValue),
      )
      ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]);
    return query.get();
  }

  Stream<List<Op>> watchPendingOps() {
    final query = select(ops)
      ..where((o) => o.needsSync.equals(true))
      ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]);
    return query.watch();
  }

  Future<void> markApplied(String opIdValue) async {
    await (update(ops)..where((o) => o.opId.equals(opIdValue))).write(
      OpsCompanion(
        isApplied: const Value(true),
        appliedAt: Value(DateTime.now()),
        needsSync: const Value(false),
      ),
    );
  }
}

