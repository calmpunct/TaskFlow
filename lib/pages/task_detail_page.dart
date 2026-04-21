import 'package:flutter/material.dart';
import 'package:taskflow/models/task_item.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    this.initialTask,
    this.availableLists = const <String>['收集箱'],
  });

  final TaskItem? initialTask;
  final List<String> availableLists;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _selectedList;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialTask?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialTask?.description ?? '',
    );
    _selectedList = widget.initialTask?.listName ?? '收集箱';
    if (!widget.availableLists.contains(_selectedList) &&
        _selectedList.isNotEmpty) {
      _selectedList = '收集箱';
    }
    _dueAt = widget.initialTask?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dueAt == null ? '未设置时间' : _formatDateTime(_dueAt!);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTask == null ? '新建任务' : '编辑任务'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '任务名字',
              hintText: '例如：准备周会材料',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '描述',
              alignLabelWithHint: true,
              hintText: '写下任务细节',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedList,
            decoration: const InputDecoration(labelText: '清单'),
            items: widget.availableLists
                .map(
                  (listName) => DropdownMenuItem<String>(
                    value: listName,
                    child: Text(listName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedList = value;
              });
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('时间'),
            subtitle: Text(dateText),
            trailing: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('选择'),
                ),
                TextButton(
                  onPressed: _dueAt == null
                      ? null
                      : () {
                          setState(() {
                            _dueAt = null;
                          });
                        },
                  child: const Text('清除'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存任务'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || date == null) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务名字不能为空')),
      );
      return;
    }

    final now = DateTime.now();
    final saved = (widget.initialTask ??
            TaskItem(
              id: now.microsecondsSinceEpoch.toString(),
              title: title,
              createdAt: now,
              listName: _selectedList,
            ))
        .copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          listName: _selectedList,
          dueAt: _dueAt,
          clearDueAt: _dueAt == null,
        );

    Navigator.of(context).pop(saved);
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
