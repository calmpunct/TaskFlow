import 'package:flutter/material.dart';
import 'package:taskflow/data/sync/object_storage_config_manager.dart';
import 'package:taskflow/data/sync/sync_config_repository.dart';
import 'package:taskflow/data/sync/sync_engine.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/pages/calendar_page.dart';
import 'package:taskflow/pages/countdown_page.dart';
import 'package:taskflow/pages/focus_page.dart';
import 'package:taskflow/pages/settings_page.dart';
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

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isTaskDrawerOpen = false;
  TaskSyncAction? _taskSyncAction;
  bool _shellSyncing = false;
  late final AnimationController _syncRotationController;

  late final List<Widget> _pages = [
    TaskPage(
      repository: widget.repository,
      syncEngine: widget.syncEngine,
      syncConfigRepository: widget.syncConfigRepository,
      onSyncActionChanged: (action) {
        if (_taskSyncAction == action) {
          return;
        }
        _taskSyncAction = action;
        if (!mounted) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {});
        });
      },
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
    _syncRotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _syncOnEnter();
  }

  @override
  void dispose() {
    _syncRotationController.dispose();
    super.dispose();
  }

  Future<void> _syncOnEnter() async {
    try {
      await widget.syncEngine.syncNow();
    } catch (_) {
      // Keep startup resilient; detailed error is already emitted by SyncEngine.
    }
  }

  bool _isLargeScreen(double width) {
    return width >= 900;
  }

  Future<void> _triggerTaskSync() async {
    if (_shellSyncing || _taskSyncAction == null) {
      return;
    }

    setState(() {
      _shellSyncing = true;
    });
    _syncRotationController.repeat();

    try {
      await _taskSyncAction!.call();
    } finally {
      if (mounted) {
        _syncRotationController.stop();
        setState(() {
          _shellSyncing = false;
        });
      }
    }
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          configManager: widget.configManager,
          syncEngine: widget.syncEngine,
        ),
      ),
    );
  }

  Widget _buildWideNavRail() {
    final sidebarWidth = 80.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: '设置',
                onPressed: _openSettingsPage,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                labelType: NavigationRailLabelType.all,
                destinations: _tabs
                    .map(
                      (tab) => NavigationRailDestination(
                        icon: Icon(tab.icon),
                        label: Text(tab.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      (_currentIndex == 0 && _taskSyncAction != null)
                          ? _triggerTaskSync
                          : null,
                  icon: RotationTransition(
                    turns: _syncRotationController,
                    child: const Icon(Icons.sync_rounded),
                  ),
                  label: const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = _isLargeScreen(constraints.maxWidth);
        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                _buildWideNavRail(),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _pages),
                ),
              ],
            ),
          );
        }

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
      },
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
