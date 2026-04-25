import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/pages/widgets/object_storage_config_panel.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({
    super.key,
    required this.configManager,
  });

  final ObjectStorageConfigManager configManager;

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ObjectStorageConfigPanel(
            configManager: widget.configManager,
          ),
        ),
      ),
    );
  }
}

