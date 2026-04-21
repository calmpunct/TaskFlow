import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taskflow/models/anniversary_item.dart';
import 'package:taskflow/pages/anniversary_editor_sheet.dart';

class AnniversaryDetailResult {
  const AnniversaryDetailResult.edit(this.item) : deleted = false;

  const AnniversaryDetailResult.delete()
      : item = null,
        deleted = true;

  final AnniversaryItem? item;
  final bool deleted;
}

class AnniversaryDetailPage extends StatefulWidget {
  const AnniversaryDetailPage({super.key, required this.item});

  final AnniversaryItem item;

  @override
  State<AnniversaryDetailPage> createState() => _AnniversaryDetailPageState();
}

class _AnniversaryDetailPageState extends State<AnniversaryDetailPage> {
  late AnniversaryItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final dayInfo = _buildDayInfo(_item.date);
    return Scaffold(
      appBar: AppBar(
        title: const Text('纪念日详情'),
        actions: [
          PopupMenuButton<_DetailAction>(
            onSelected: (action) => _onMenuAction(action),
            itemBuilder: (context) => const [
              PopupMenuItem<_DetailAction>(
                value: _DetailAction.edit,
                child: Text('编辑'),
              ),
              PopupMenuItem<_DetailAction>(
                value: _DetailAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _buildLeading(_item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buildTitle(_item),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('日期: ${_formatDate(_item.date)}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                dayInfo.isUpcoming ? Icons.hourglass_top_rounded : Icons.history_rounded,
              ),
              title: Text(dayInfo.text),
              subtitle: Text(dayInfo.isUpcoming ? '距离下一次纪念日' : '本年度纪念日已过去'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('提醒'),
              subtitle: Text(_item.reminderText),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.push_pin_rounded),
              title: const Text('置顶'),
              subtitle: Text(_item.isPinned ? '是' : '否'),
            ),
          ),
          if (_item.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: const Text('备注'),
                subtitle: Text(_item.note),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeading(AnniversaryItem item) {
    if (item.iconType == AnniversaryIconType.image &&
        item.imagePath != null &&
        item.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(
          File(item.imagePath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CircleAvatar(
            radius: 24,
            child: Icon(item.builtInIcon),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 24,
      child: Icon(item.builtInIcon),
    );
  }

  String _buildTitle(AnniversaryItem item) {
    if (!item.isBirthday) {
      return item.name;
    }
    return '${item.name} (${_nextAge(item)}岁)';
  }

  int _nextAge(AnniversaryItem item) {
    final nextOccurrence = _nextOccurrence(item.date);
    return nextOccurrence.year - item.date.year;
  }

  DateTime _nextOccurrence(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var target = DateTime(today.year, date.month, date.day);
    if (target.isBefore(today)) {
      target = DateTime(today.year + 1, date.month, date.day);
    }
    return target;
  }

  _DayInfo _buildDayInfo(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisYear = DateTime(today.year, date.month, date.day);
    if (today.isAfter(thisYear)) {
      final passed = today.difference(thisYear).inDays;
      return _DayInfo(text: '已过天数$passed', isUpcoming: false);
    }

    final days = thisYear.difference(today).inDays;
    return _DayInfo(text: '天数$days', isUpcoming: true);
  }

  String _formatDate(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  Future<void> _onMenuAction(_DetailAction action) async {
    switch (action) {
      case _DetailAction.edit:
        final edited = await showModalBottomSheet<AnniversaryItem>(
          context: context,
          isScrollControlled: true,
          builder: (context) => AnniversaryEditorSheet(initialItem: _item),
        );
        if (!mounted || edited == null) {
          return;
        }
        setState(() {
          _item = edited;
        });
        Navigator.of(context).pop(AnniversaryDetailResult.edit(edited));
        break;
      case _DetailAction.delete:
        Navigator.of(context).pop(const AnniversaryDetailResult.delete());
        break;
    }
  }
}

class _DayInfo {
  const _DayInfo({required this.text, required this.isUpcoming});

  final String text;
  final bool isUpcoming;
}

enum _DetailAction { edit, delete }

