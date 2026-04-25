import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_config_repository.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/pages/calendar_page.dart';
import 'package:taskflow/pages/countdown_page.dart';
import 'package:taskflow/pages/focus_page.dart';
import 'package:taskflow/pages/task_page.dart';

class HomeShell extends StatefulWidget {
  HomeShell({
    super.key,
    TaskRepository? repository,
    SyncEngine? syncEngine,
    SyncConfigRepository? syncConfigRepository,
    ObjectStorageConfigManager? configManager,
  }) : repository = repository ?? DriftTaskRepository(),
       syncEngine = syncEngine ?? NoopSyncEngine(),
       syncConfigRepository =
           syncConfigRepository ?? SharedPrefsSyncConfigRepository(),
       configManager =
           configManager ??
           ObjectStorageConfigManager(
             configRepository:
                 syncConfigRepository ?? SharedPrefsSyncConfigRepository(),
             syncEngine: syncEngine ?? NoopSyncEngine(),
           );

  final TaskRepository repository;
  final SyncEngine syncEngine;
  final SyncConfigRepository syncConfigRepository;
  final ObjectStorageConfigManager configManager;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _isTaskDrawerOpen = false;

  late final List<Widget> _pages = [
    TaskPage(
      repository: widget.repository,
      syncEngine: widget.syncEngine,
      syncConfigRepository: widget.syncConfigRepository,
      onDrawerChanged: (isOpen) {
        if (_isTaskDrawerOpen == isOpen) {
          return;
        }
        setState(() {
          _isTaskDrawerOpen = isOpen;
        });
      },
    ),
    const FocusPage(),
    const CalendarPage(),
    CountdownPage(repository: widget.repository),
  ];

  static const List<_TabItem> _tabs = <_TabItem>[
    _TabItem(label: '任务', icon: Icons.checklist_rounded),
    _TabItem(label: '专注', icon: Icons.timer_rounded),
    _TabItem(label: '日历', icon: Icons.calendar_month_rounded),
    _TabItem(label: '纪念日', icon: Icons.flag_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _syncOnEnter();
  }

  Future<void> _syncOnEnter() async {
    try {
      await widget.syncEngine.syncNow();
    } catch (_) {
      // Keep startup resilient; detailed error is already emitted by SyncEngine.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _isTaskDrawerOpen
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: _tabs
                  .map(
                    (tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
