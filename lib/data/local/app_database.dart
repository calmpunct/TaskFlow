import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';
part 'tables/tasks_table.dart';
part 'tables/ops_table.dart';
part 'tables/devices_table.dart';
part 'tables/sync_state_table.dart';
part 'tables/anniversaries_table.dart';
part 'tables/custom_lists_table.dart';
part 'daos/task_dao.dart';
part 'daos/ops_dao.dart';
part 'daos/device_dao.dart';
part 'daos/sync_state_dao.dart';
part 'daos/anniversary_dao.dart';
part 'daos/custom_list_dao.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'taskflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [Tasks, Ops, Devices, SyncStates, Anniversaries, CustomLists],
  daos: [
    TaskDao,
    OpsDao,
    DeviceDao,
    SyncStateDao,
    AnniversaryDao,
    CustomListDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  static AppDatabase? _instance;

  factory AppDatabase.instance() => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_tasks_status_due ON tasks(status, due_at);',
          );
          await customStatement(
            'CREATE INDEX idx_tasks_list_status ON tasks(list_name, status);',
          );
          await customStatement(
            'CREATE INDEX idx_tasks_updated ON tasks(updated_at);',
          );
          await customStatement(
            'CREATE INDEX idx_ops_needs_sync_created_at ON ops(needs_sync, created_at);',
          );
          await customStatement(
            'CREATE INDEX idx_ops_entity_created_at ON ops(entity_type, entity_id, created_at);',
          );
          await customStatement(
            'CREATE INDEX idx_ops_created_at ON ops(created_at);',
          );
          await customStatement(
            'CREATE INDEX idx_devices_is_current ON devices(is_current);',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_sync_state_scope ON sync_states(scope);',
          );
        },
      );
}

