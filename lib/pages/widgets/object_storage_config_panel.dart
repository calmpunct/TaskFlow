import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_storage_config.dart';

/// 对象存储配置面板 - 独立可复用的配置UI组件
class ObjectStorageConfigPanel extends StatefulWidget {
  const ObjectStorageConfigPanel({
    super.key,
    required this.configManager,
    this.onConfigSaved,
  });

  final ObjectStorageConfigManager configManager;
  final VoidCallback? onConfigSaved;

  @override
  State<ObjectStorageConfigPanel> createState() =>
      _ObjectStorageConfigPanelState();
}

class _ObjectStorageConfigPanelState extends State<ObjectStorageConfigPanel> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController();
  final _bucketController = TextEditingController();
  final _folderController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _enabled = false;
  bool _usePathStyle = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
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

  Future<void> _loadConfig() async {
    final config = await widget.configManager.loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = config.enabled;
      _usePathStyle = config.usePathStyle;
      _endpointController.text = config.endpoint;
      _regionController.text = config.region;
      _bucketController.text = config.bucket;
      _folderController.text = config.folder;
      _accessKeyController.text = config.accessKey;
      _secretKeyController.text = config.secretKey;
      _loading = false;
    });
  }

  SyncStorageConfig _buildConfigFromForm() {
    return SyncStorageConfig(
      enabled: _enabled,
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
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });
    final config = _buildConfigFromForm();
    try {
      await widget.configManager.saveConfig(config);
      if (!mounted) {
        return;
      }
      _showSnack('配置已保存');
      widget.onConfigSaved?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('保存失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _testing = true;
    });

    try {
      await widget.configManager.testConnection(_buildConfigFromForm());
      if (!mounted) {
        return;
      }
      _showSnack('连接测试成功');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('连接失败: $error');
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
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('启用对象存储同步'),
                    subtitle: const Text('进入软件时自动执行一次同步'),
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                      });
                    },
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildField(
                          controller: _endpointController,
                          label: 'Endpoint',
                          hint: '例如: s3.amazonaws.com 或对象存储域名',
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _regionController,
                          label: 'Region',
                          hint: '例如: us-east-1',
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _bucketController,
                          label: 'Bucket',
                          hint: '对象存储桶名称',
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _folderController,
                          label: '目录',
                          hint: '例如: taskflow-sync',
                          required: false,
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _accessKeyController,
                          label: 'Access Key',
                          hint: 'AK',
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _secretKeyController,
                          label: 'Secret Key',
                          hint: 'SK',
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(_testing ? '测试中...' : '测试连接'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveConfig,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? '保存中...' : '保存配置'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) {
              if ((value ?? '').trim().isEmpty) {
                return '$label 不能为空';
              }
              return null;
            }
          : null,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

