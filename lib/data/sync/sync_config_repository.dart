import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow/data/sync/sync_storage_config.dart';

abstract class SyncConfigRepository {
  Future<SyncStorageConfig> load();

  Future<void> save(SyncStorageConfig config);
}

class SharedPrefsSyncConfigRepository implements SyncConfigRepository {
  static const String _enabledKey = 'sync.s3.enabled';
  static const String _endpointKey = 'sync.s3.endpoint';
  static const String _regionKey = 'sync.s3.region';
  static const String _bucketKey = 'sync.s3.bucket';
  static const String _folderKey = 'sync.s3.folder';
  static const String _accessKeyKey = 'sync.s3.accessKey';
  static const String _secretKeyKey = 'sync.s3.secretKey';
  static const String _pathStyleKey = 'sync.s3.pathStyle';

  @override
  Future<SyncStorageConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncStorageConfig(
      enabled: prefs.getBool(_enabledKey) ?? false,
      endpoint: prefs.getString(_endpointKey) ?? '',
      region: prefs.getString(_regionKey) ?? 'us-east-1',
      bucket: prefs.getString(_bucketKey) ?? '',
      folder: prefs.getString(_folderKey) ?? 'taskflow-sync',
      accessKey: prefs.getString(_accessKeyKey) ?? '',
      secretKey: prefs.getString(_secretKeyKey) ?? '',
      usePathStyle: prefs.getBool(_pathStyleKey) ?? true,
    );
  }

  @override
  Future<void> save(SyncStorageConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setString(_endpointKey, config.endpoint.trim());
    await prefs.setString(_regionKey, config.region.trim());
    await prefs.setString(_bucketKey, config.bucket.trim());
    await prefs.setString(_folderKey, config.folder.trim());
    await prefs.setString(_accessKeyKey, config.accessKey.trim());
    await prefs.setString(_secretKeyKey, config.secretKey.trim());
    await prefs.setBool(_pathStyleKey, config.usePathStyle);
  }
}
