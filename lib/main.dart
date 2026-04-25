import 'package:flutter/material.dart';
import 'package:taskflow/data/local/app_database.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_config_repository.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.instance();
  final repository = DriftTaskRepository(database: db);
  final syncConfigRepository = SharedPrefsSyncConfigRepository();
  final syncEngine = S3SyncEngine(
    database: db,
    configRepository: syncConfigRepository,
  );
  final configManager = ObjectStorageConfigManager(
    configRepository: syncConfigRepository,
    syncEngine: syncEngine,
  );

  runApp(
    MyApp(
      repository: repository,
      syncEngine: syncEngine,
      syncConfigRepository: syncConfigRepository,
      configManager: configManager,
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    TaskRepository? repository,
    SyncEngine? syncEngine,
    SyncConfigRepository? syncConfigRepository,
    ObjectStorageConfigManager? configManager,
  }) : repository =
           repository ?? DriftTaskRepository(database: AppDatabase.instance()),
       syncConfigRepository =
           syncConfigRepository ?? SharedPrefsSyncConfigRepository(),
       syncEngine =
           syncEngine ??
           S3SyncEngine(
             database: AppDatabase.instance(),
             configRepository:
                 syncConfigRepository ?? SharedPrefsSyncConfigRepository(),
           ),
       configManager =
           configManager ??
           ObjectStorageConfigManager(
             configRepository:
                 syncConfigRepository ?? SharedPrefsSyncConfigRepository(),
             syncEngine:
                 syncEngine ??
                 S3SyncEngine(
                   database: AppDatabase.instance(),
                   configRepository:
                       syncConfigRepository ??
                       SharedPrefsSyncConfigRepository(),
                 ),
           );

  final TaskRepository repository;
  final SyncEngine syncEngine;
  final SyncConfigRepository syncConfigRepository;
  final ObjectStorageConfigManager configManager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskflow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeShell(
        repository: repository,
        syncEngine: syncEngine,
        syncConfigRepository: syncConfigRepository,
        configManager: configManager,
      ),
    );
  }
}
