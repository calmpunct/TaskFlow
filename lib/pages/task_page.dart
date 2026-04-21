import 'package:flutter/material.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/models/task_item.dart';
import 'package:taskflow/pages/settings_page.dart';
import 'package:taskflow/pages/task_detail_page.dart';

class TaskPage extends StatefulWidget {
  TaskPage({
    super.key,
    TaskRepository? repository,
    this.onDrawerChanged,
  })
      : repository = repository ?? HiveTaskRepository();

  final TaskRepository repository;
  final ValueChanged<bool>? onDrawerChanged;

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  static const String _inboxListName = '收集箱';

  List<TaskItem> _tasks = <TaskItem>[];
  List<String> _customLists = <String>[];
  TaskFilter? _currentFilter = TaskFilter.inbox;
  String? _currentCustomList;
  bool _loading = true;

  static const List<TaskFilter> _filters = <TaskFilter>[
    TaskFilter.today,
    TaskFilter.tomorrow,
    TaskFilter.next7Days,
    TaskFilter.inbox,
    TaskFilter.completed,
    TaskFilter.trashed,
    TaskFilter.abandoned,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loadedTasks = await widget.repository.loadTasks();
    final loadedLists = await widget.repository.loadCustomLists();
    final tasks = loadedTasks.isEmpty ? _seedTasks() : loadedTasks;
    final lists = loadedLists.where((name) => name != _inboxListName).toSet().toList()
      ..sort();

    if (loadedTasks.isEmpty) {
      await widget.repository.saveTasks(tasks);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _tasks = tasks;
      _customLists = lists;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _currentCustomList == null
        ? _applySystemFilter(_tasks, _currentFilter!)
        : _applyListFilter(_tasks, _currentCustomList!);

    return Scaffold(
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.3,
      onDrawerChanged: widget.onDrawerChanged,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.deepPurple),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.person_rounded),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Taskflow 用户',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _showComingSoon('我的信息'),
                          icon: const Icon(Icons.notifications_active, color: Colors.white),
                          tooltip: '我的信息',
                        ),
                        IconButton(
                          onPressed: _openSettingsPage,
                          icon: const Icon(Icons.settings, color: Colors.white),
                          tooltip: '设置',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ..._filters.map(_buildSystemFilterTile),
              const Divider(height: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('我的清单'),
              ),
              ..._customLists.map(_buildCustomListTile),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('创建清单'),
                onTap: _createCustomList,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: '打开侧边栏',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(_currentCustomList ?? _currentFilter!.label),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filteredTasks.isEmpty
              ? Center(
                  child: Text(
                    '${_currentCustomList ?? _currentFilter!.label}暂无任务',
                  ),
                )
              : ListView.separated(
                  itemCount: filteredTasks.length,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _editTask(task),
                        leading: Checkbox(
                          value: task.status == TaskStatus.completed,
                          onChanged: task.status == TaskStatus.trashed ||
                                  task.status == TaskStatus.abandoned
                              ? null
                              : (checked) {
                                  final status = (checked ?? false)
                                      ? TaskStatus.completed
                                      : TaskStatus.inbox;
                                  _updateTask(task.copyWith(status: status));
                                },
                        ),
                        title: Text(task.title),
                        subtitle: Text(_buildSubtitle(task)),
                        trailing: PopupMenuButton<_TaskAction>(
                          onSelected: (action) => _onTaskAction(task, action),
                          itemBuilder: (_) => _buildTaskActions(task),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTask,
        icon: const Icon(Icons.add),
        label: const Text('添加任务'),
      ),
    );
  }

  Widget _buildSystemFilterTile(TaskFilter filter) {
    return ListTile(
      leading: Icon(_iconForFilter(filter)),
      title: Text(filter.label),
      selected: _currentCustomList == null && filter == _currentFilter,
      onTap: () {
        setState(() {
          _currentFilter = filter;
          _currentCustomList = null;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildCustomListTile(String listName) {
    return ListTile(
      leading: const Icon(Icons.checklist_rounded),
      title: Text(listName),
      selected: _currentCustomList == listName,
      onTap: () {
        setState(() {
          _currentCustomList = listName;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _createCustomList() async {
    final controller = TextEditingController();
    final newListName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建清单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入清单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (!mounted || newListName == null || newListName.isEmpty) {
      return;
    }

    if (newListName == _inboxListName || _customLists.contains(newListName)) {
      _showSnack('清单已存在');
      return;
    }

    setState(() {
      _customLists = <String>[..._customLists, newListName]..sort();
      _currentCustomList = newListName;
    });
    await widget.repository.saveCustomLists(_customLists);
  }

  List<TaskItem> _seedTasks() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return <TaskItem>[
      TaskItem(
        id: 'seed-1',
        title: '整理今天的待办事项',
        description: '把今天必须做的任务放入收集箱',
        dueAt: DateTime(now.year, now.month, now.day, 20, 0),
        createdAt: now,
        listName: _inboxListName,
      ),
      TaskItem(
        id: 'seed-2',
        title: '完成 30 分钟深度专注',
        dueAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 30),
        createdAt: now,
        listName: _inboxListName,
      ),
      TaskItem(
        id: 'seed-3',
        title: '查看本周日历安排',
        createdAt: now,
        listName: _inboxListName,
      ),
    ];
  }

  List<TaskItem> _applyListFilter(List<TaskItem> source, String listName) {
    return source
        .where(
          (task) => task.status == TaskStatus.inbox && task.listName == listName,
        )
        .toList();
  }

  List<TaskItem> _applySystemFilter(List<TaskItem> source, TaskFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final afterWeek = today.add(const Duration(days: 7));

    bool isSameDay(DateTime first, DateTime second) {
      return first.year == second.year &&
          first.month == second.month &&
          first.day == second.day;
    }

    bool inRange(DateTime target, DateTime start, DateTime end) {
      final date = DateTime(target.year, target.month, target.day);
      return !date.isBefore(start) && date.isBefore(end);
    }

    switch (filter) {
      case TaskFilter.today:
        return source
            .where(
              (task) =>
                  task.status == TaskStatus.inbox &&
                  task.dueAt != null &&
                  isSameDay(task.dueAt!, today),
            )
            .toList();
      case TaskFilter.tomorrow:
        return source
            .where(
              (task) =>
                  task.status == TaskStatus.inbox &&
                  task.dueAt != null &&
                  isSameDay(task.dueAt!, tomorrow),
            )
            .toList();
      case TaskFilter.next7Days:
        return source
            .where(
              (task) =>
                  task.status == TaskStatus.inbox &&
                  task.dueAt != null &&
                  inRange(task.dueAt!, today, afterWeek),
            )
            .toList();
      case TaskFilter.inbox:
        return source
            .where(
              (task) =>
                  task.status == TaskStatus.inbox &&
                  task.listName == _inboxListName,
            )
            .toList();
      case TaskFilter.completed:
        return source
            .where((task) => task.status == TaskStatus.completed)
            .toList();
      case TaskFilter.trashed:
        return source.where((task) => task.status == TaskStatus.trashed).toList();
      case TaskFilter.abandoned:
        return source
            .where((task) => task.status == TaskStatus.abandoned)
            .toList();
    }
  }

  String _buildSubtitle(TaskItem task) {
    final parts = <String>['清单: ${task.listName}'];
    if (task.description.isNotEmpty) {
      parts.add(task.description);
    }
    if (task.dueAt != null) {
      parts.add('时间: ${_formatDateTime(task.dueAt!)}');
    }
    return parts.join('  |  ');
  }

  IconData _iconForFilter(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.today:
        return Icons.today_rounded;
      case TaskFilter.tomorrow:
        return Icons.wb_sunny_outlined;
      case TaskFilter.next7Days:
        return Icons.date_range_rounded;
      case TaskFilter.inbox:
        return Icons.inbox_rounded;
      case TaskFilter.completed:
        return Icons.done_all_rounded;
      case TaskFilter.trashed:
        return Icons.delete_outline_rounded;
      case TaskFilter.abandoned:
        return Icons.block_rounded;
    }
  }

  List<PopupMenuEntry<_TaskAction>> _buildTaskActions(TaskItem task) {
    final entries = <PopupMenuEntry<_TaskAction>>[];
    if (task.status != TaskStatus.inbox) {
      entries.add(
        const PopupMenuItem<_TaskAction>(
          value: _TaskAction.moveToInbox,
          child: Text('移动到收集箱'),
        ),
      );
    }
    if (task.status != TaskStatus.completed) {
      entries.add(
        const PopupMenuItem<_TaskAction>(
          value: _TaskAction.complete,
          child: Text('标记完成'),
        ),
      );
    }
    if (task.status != TaskStatus.abandoned) {
      entries.add(
        const PopupMenuItem<_TaskAction>(
          value: _TaskAction.abandon,
          child: Text('标记放弃'),
        ),
      );
    }
    if (task.status != TaskStatus.trashed) {
      entries.add(
        const PopupMenuItem<_TaskAction>(
          value: _TaskAction.trash,
          child: Text('移动到垃圾桶'),
        ),
      );
    }
    return entries;
  }

  Future<void> _onTaskAction(TaskItem task, _TaskAction action) async {
    switch (action) {
      case _TaskAction.moveToInbox:
        await _updateTask(
          task.copyWith(status: TaskStatus.inbox, listName: _inboxListName),
        );
        break;
      case _TaskAction.complete:
        await _updateTask(task.copyWith(status: TaskStatus.completed));
        break;
      case _TaskAction.abandon:
        await _updateTask(task.copyWith(status: TaskStatus.abandoned));
        break;
      case _TaskAction.trash:
        await _updateTask(task.copyWith(status: TaskStatus.trashed));
        break;
    }
  }

  Future<void> _createTask() async {
    final created = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute<TaskItem>(
        builder: (_) => TaskDetailPage(availableLists: _allLists),
      ),
    );
    if (!mounted || created == null) {
      return;
    }

    setState(() {
      _tasks.insert(0, created.copyWith(status: TaskStatus.inbox));
      _currentFilter = TaskFilter.inbox;
      _currentCustomList = null;
    });
    await widget.repository.saveTasks(_tasks);
  }

  Future<void> _editTask(TaskItem task) async {
    final updated = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute<TaskItem>(
        builder: (_) => TaskDetailPage(
          initialTask: task,
          availableLists: _allLists,
        ),
      ),
    );
    if (!mounted || updated == null) {
      return;
    }

    await _updateTask(updated.copyWith(status: task.status));
  }

  Future<void> _updateTask(TaskItem updatedTask) async {
    setState(() {
      _tasks = _tasks
          .map((task) => task.id == updatedTask.id ? updatedTask : task)
          .toList();
    });
    await widget.repository.saveTasks(_tasks);
  }

  List<String> get _allLists => <String>[_inboxListName, ..._customLists];

  String _formatDateTime(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  void _showComingSoon(String label) {
    _showSnack('$label 功能即将上线');
  }

  Future<void> _openSettingsPage() async {
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

enum _TaskAction {
  moveToInbox,
  complete,
  abandon,
  trash,
}
