import 'package:taskflow/data/sync/sync_config_repository.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/data/sync/sync_storage_config.dart';

/// 对象存储配置管理器 - 封装配置相关的业务逻辑
class ObjectStorageConfigManager {
  ObjectStorageConfigManager({
    required SyncConfigRepository configRepository,
    required SyncEngine syncEngine,
  })  : _configRepository = configRepository,
        _syncEngine = syncEngine;

  final SyncConfigRepository _configRepository;
  final SyncEngine _syncEngine;

  /// 加载当前配置
  Future<SyncStorageConfig> loadConfig() {
    return _configRepository.load();
  }

  /// 保存配置
  Future<void> saveConfig(SyncStorageConfig config) {
    return _configRepository.save(config);
  }

  /// 测试连接
  Future<void> testConnection(SyncStorageConfig config) {
    return _syncEngine.testConnection(config);
  }

  /// 立即同步
  Future<void> syncNow() {
    return _syncEngine.syncNow();
  }

  /// 监听同步进度
  Stream<SyncProgress> watchSyncProgress() {
    return _syncEngine.watchProgress();
  }
}

