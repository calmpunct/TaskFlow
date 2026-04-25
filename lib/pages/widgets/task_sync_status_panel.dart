import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/sync_engine.dart';

/// Task Sync Status Panel - Shows task sync and countdown information
class TaskSyncStatusPanel extends StatefulWidget {
  const TaskSyncStatusPanel({
    super.key,
    required this.syncEngine,
  });

  final SyncEngine syncEngine;

  @override
  State<TaskSyncStatusPanel> createState() => _TaskSyncStatusPanelState();
}

class _TaskSyncStatusPanelState extends State<TaskSyncStatusPanel> {
  late final Stream<SyncProgress> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = widget.syncEngine.watchProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_rounded, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '任务同步状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '实时跟踪任务状态和倒计时',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<SyncProgress>(
              stream: _progressStream,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? const SyncProgress(isSyncing: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow(
                      icon: progress.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              progress.lastMessage?.contains('失败') == true
                                  ? Icons.error_rounded
                                  : Icons.check_circle_rounded,
                              size: 16,
                              color: progress.lastMessage?.contains('失败') == true
                                  ? Colors.red
                                  : Colors.green,
                            ),
                      label: '状态',
                      value: progress.lastMessage ?? '等待中...',
                    ),
                    const SizedBox(height: 8),
                    if (progress.lastSyncAt != null)
                      _buildStatusRow(
                        icon: const Icon(Icons.schedule_rounded, size: 16),
                        label: '最后同步',
                        value: _formatTime(progress.lastSyncAt!),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _buildFeatureList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required Widget icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    const features = [
      ('多设备任务同步', '在所有设备间实时同步任务状态'),
      ('倒计时跟踪', '同步任务截止日期和倒计时天数'),
      ('状态变更记录', '记录并同步所有任务状态变更'),
      ('冲突自动解决', '采用最新版本作为同步标准'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          '同步功能',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...features.map((feature) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.$1,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        feature.$2,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    } else {
      return '${diff.inDays} 天前';
    }
  }
}

