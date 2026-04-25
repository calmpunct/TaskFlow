import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/pages/widgets/object_storage_config_panel.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TaskSyncStatusPanel(
                  syncEngine: widget.syncEngine,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ObjectStorageConfigPanel(
                  configManager: widget.configManager,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

