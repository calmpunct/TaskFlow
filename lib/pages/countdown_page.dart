import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/models/anniversary_item.dart';
import 'package:taskflow/pages/anniversary_editor_sheet.dart';

class CountdownPage extends StatefulWidget {
  CountdownPage({super.key, TaskRepository? repository})
      : repository = repository ?? HiveTaskRepository();

  final TaskRepository repository;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  List<AnniversaryItem> _anniversaries = <AnniversaryItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnniversaries();
  }

  Future<void> _loadAnniversaries() async {
    final loaded = await widget.repository.loadAnniversaries();
    if (!mounted) {
      return;
    }

    setState(() {
      _anniversaries = _sorted(loaded);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _sorted(_anniversaries);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('纪念日'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _buildEmptyView(context)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _openEditor(item),
                        leading: _buildLeading(item),
                        title: Text(item.name),
                        subtitle: Text(_buildSubtitle(item)),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.isPinned)
                              const Icon(Icons.push_pin_rounded, size: 18),
                            PopupMenuButton<_AnniversaryAction>(
                              onSelected: (action) => _onAction(item, action),
                              itemBuilder: (_) => const [
                                PopupMenuItem<_AnniversaryAction>(
                                  value: _AnniversaryAction.edit,
                                  child: Text('编辑'),
                                ),
                                PopupMenuItem<_AnniversaryAction>(
                                  value: _AnniversaryAction.delete,
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加纪念日'),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_rounded, size: 56),
          const SizedBox(height: 12),
          Text('还没有纪念日', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('点击右下角添加你的第一个纪念日'),
        ],
      ),
    );
  }

  Widget _buildLeading(AnniversaryItem item) {
    if (item.iconType == AnniversaryIconType.image &&
        item.imagePath != null &&
        item.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(item.imagePath!),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CircleAvatar(
            child: Icon(item.builtInIcon),
          ),
        ),
      );
    }
    return CircleAvatar(
      child: Icon(item.builtInIcon),
    );
  }

  String _buildSubtitle(AnniversaryItem item) {
    final days = _daysUntil(item.date);
    final datePart = '日期: ${_formatDate(item.date)}';
    final dayPart = days == 0 ? '今天' : '还有 $days 天';
    final reminderPart = '提醒: ${item.reminder.label}';
    final notePart = item.note.isEmpty ? '' : ' | ${item.note}';
    return '$datePart | $dayPart | $reminderPart$notePart';
  }

  Future<void> _openEditor([AnniversaryItem? item]) async {
    final saved = await showModalBottomSheet<AnniversaryItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AnniversaryEditorSheet(initialItem: item),
    );

    if (!mounted || saved == null) {
      return;
    }

    setState(() {
      if (item == null) {
        _anniversaries = <AnniversaryItem>[saved, ..._anniversaries];
      } else {
        _anniversaries = _anniversaries
            .map((current) => current.id == saved.id ? saved : current)
            .toList();
      }
      _anniversaries = _sorted(_anniversaries);
    });
    await widget.repository.saveAnniversaries(_anniversaries);
  }

  Future<void> _onAction(AnniversaryItem item, _AnniversaryAction action) async {
    switch (action) {
      case _AnniversaryAction.edit:
        await _openEditor(item);
        break;
      case _AnniversaryAction.delete:
        setState(() {
          _anniversaries = _anniversaries.where((value) => value.id != item.id).toList();
        });
        await widget.repository.saveAnniversaries(_anniversaries);
        break;
    }
  }

  List<AnniversaryItem> _sorted(List<AnniversaryItem> source) {
    final copied = List<AnniversaryItem>.from(source);
    copied.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return _daysUntil(a.date).compareTo(_daysUntil(b.date));
    });
    return copied;
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var target = DateTime(today.year, date.month, date.day);
    if (target.isBefore(today)) {
      target = DateTime(today.year + 1, date.month, date.day);
    }
    return target.difference(today).inDays;
  }

  String _formatDate(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }
}

enum _AnniversaryAction { edit, delete }

