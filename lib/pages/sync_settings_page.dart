import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/data/sync/sync_storage_config.dart';
import 'package:taskflow/pages/widgets/task_sync_status_panel.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({
    super.key,
    required this.configManager,
    required this.syncEngine,
  });

  final ObjectStorageConfigManager configManager;
  final SyncEngine syncEngine;

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  SyncStorageConfig? _config;
  bool _autoSync = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final config = await widget.configManager.loadConfig();
    // Load auto sync setting from shared preferences or config manager
    // For now, we'll use the enabled flag as auto sync
    setState(() {
      _config = config;
      _autoSync = config.enabled;
      _loading = false;
    });
  }

  Future<void> _showS3ConfigDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _S3ConfigDialog(
        configManager: widget.configManager,
        initialConfig: _config,
      ),
    );
    // Reload config after dialog closes
    await _loadSettings();
  }

  Future<void> _toggleAutoSync(bool value) async {
    setState(() {
      _autoSync = value;
    });
    
    // Update config with new auto sync setting
    if (_config != null) {
      final updatedConfig = _config!.copyWith(enabled: value);
      await widget.configManager.saveConfig(updatedConfig);
      setState(() {
        _config = updatedConfig;
      });
    }
  }

  Future<void> _syncNow() async {
    if (_config == null || !_config!.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置并启用对象存储同步')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在同步...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await widget.configManager.syncNow();
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message with suggestion to check tasks
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('同步完成！请返回任务页面查看更新'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('同步设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isConfigured = _config != null && 
                         _config!.endpoint.isNotEmpty &&
                         _config!.bucket.isNotEmpty &&
                         _config!.accessKey.isNotEmpty &&
                         _config!.secretKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // S3 Configuration Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_rounded),
                  title: const Text('S3 配置'),
                  subtitle: Text(
                    isConfigured ? '已配置' : '未配置',
                    style: TextStyle(
                      color: isConfigured ? Colors.green : Colors.orange,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showS3ConfigDialog,
                ),
              ),
              
              if (!isConfigured)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, 
                        size: 16, 
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          '请先配置 S3 以启用同步功能',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Task Sync Status Panel with Sync Button in top-right corner
              TaskSyncStatusPanel(
                syncEngine: widget.syncEngine,
                onSyncPressed: _syncNow,
                isConfigured: isConfigured,
              ),

              const SizedBox(height: 16),

              // Auto Sync on Startup Switch
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('启动时自动同步'),
                  subtitle: const Text('打开应用时自动执行一次同步'),
                  value: _autoSync,
                  onChanged: isConfigured ? _toggleAutoSync : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// S3 Config Dialog
class _S3ConfigDialog extends StatefulWidget {
  const _S3ConfigDialog({
    required this.configManager,
    required this.initialConfig,
  });

  final ObjectStorageConfigManager configManager;
  final SyncStorageConfig? initialConfig;

  @override
  State<_S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<_S3ConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _endpointController;
  late TextEditingController _regionController;
  late TextEditingController _bucketController;
  late TextEditingController _folderController;
  late TextEditingController _accessKeyController;
  late TextEditingController _secretKeyController;
  bool _usePathStyle = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _endpointController = TextEditingController(text: config?.endpoint ?? '');
    _regionController = TextEditingController(text: config?.region ?? '');
    _bucketController = TextEditingController(text: config?.bucket ?? '');
    _folderController = TextEditingController(text: config?.folder ?? '');
    _accessKeyController = TextEditingController(text: config?.accessKey ?? '');
    _secretKeyController = TextEditingController(text: config?.secretKey ?? '');
    _usePathStyle = config?.usePathStyle ?? true;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _regionController.dispose();
    _bucketController.dispose();
    _folderController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  SyncStorageConfig _buildConfig() {
    return SyncStorageConfig(
      enabled: widget.initialConfig?.enabled ?? false,
      endpoint: _endpointController.text.trim(),
      region: _regionController.text.trim(),
      bucket: _bucketController.text.trim(),
      folder: _folderController.text.trim(),
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
      usePathStyle: _usePathStyle,
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final config = _buildConfig();
      await widget.configManager.saveConfig(config);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _testing = true;
    });

    try {
      await widget.configManager.testConnection(_buildConfig());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接测试成功')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('S3 配置'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: '例如: s3.amazonaws.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Endpoint 不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  hintText: '例如: us-east-1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bucketController,
                decoration: const InputDecoration(
                  labelText: 'Bucket',
                  hintText: '对象存储桶名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Bucket 不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _folderController,
                decoration: const InputDecoration(
                  labelText: '目录（可选）',
                  hintText: '例如: taskflow-sync',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accessKeyController,
                decoration: const InputDecoration(
                  labelText: 'Access Key',
                  hintText: 'AK',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Access Key 不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secretKeyController,
                decoration: const InputDecoration(
                  labelText: 'Secret Key',
                  hintText: 'SK',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Secret Key 不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用 Path-Style 地址'),
                subtitle: const Text('大多数兼容 S3 的对象存储建议开启'),
                value: _usePathStyle,
                onChanged: (value) {
                  setState(() {
                    _usePathStyle = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _testing ? null : _testConnection,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_testing ? '测试中...' : '测试连接'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _saveConfig,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}

