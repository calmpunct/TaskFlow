import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/pages/sync_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.configManager,
  });

  final ObjectStorageConfigManager configManager;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: ListTile(
              leading: const Icon(Icons.cloud_sync_rounded),
              title: const Text('同步设置'),
              subtitle: const Text('配置对象存储同步'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => SyncSettingsPage(
                      configManager: widget.configManager,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 16),
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('关于本软件'),
              subtitle: const Text('了解 TaskFlow 的版本与说明'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Taskflow',
                  applicationVersion: '1.0.1',
                  applicationLegalese:
                      'Taskflow - 一个任务清单与纪念日管理应用',
                  children: const [
                    SizedBox(height: 8),
                    Text('感谢使用 TaskFlow。'),
                    SizedBox(height: 6),
                    Text('作者：calmpunct'),
                    Text('官方QQ群：1091415887'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
