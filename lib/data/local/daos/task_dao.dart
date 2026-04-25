part of '../app_database.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Future<List<Task>> getAllTasks() {
    return (select(tasks)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<Task?> findById(String taskId) {
    return (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
  }

  Future<void> upsertTask(TasksCompanion entry) async {
    await into(tasks).insertOnConflictUpdate(entry);
  }

  Future<void> deleteById(String taskId) async {
    await (delete(tasks)..where((t) => t.id.equals(taskId))).go();
  }

  Future<void> replaceAll(List<TasksCompanion> entries) async {
    await transaction(() async {
      await delete(tasks).go();
      await batch((batch) {
        batch.insertAll(tasks, entries);
      });
    });
  }
}

