import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taskflow/data/task_repository.dart';
import 'package:taskflow/models/anniversary_item.dart';
import 'package:taskflow/pages/anniversary_detail_page.dart';
import 'package:taskflow/pages/anniversary_editor_sheet.dart';

class CountdownPage extends StatefulWidget {
  CountdownPage({super.key, TaskRepository? repository})
      : repository = repository ?? DriftTaskRepository();

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
                    final isBirthday = item.isBirthday;
                    return Card(
                      child: ListTile(
                        onTap: () => _openDetail(item),
                        leading: _buildLeading(item),
                        title: isBirthday
                            ? _buildBirthdayTitleRow(item)
                            : Text(_buildTitle(item)),
                        subtitle: isBirthday ? null : Text(_buildSubtitle(item)),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.isPinned)
                              const Icon(Icons.push_pin_rounded, size: 18),
                            if (!isBirthday) const Icon(Icons.chevron_right_rounded),
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

  String _buildTitle(AnniversaryItem item) {
    if (!item.isBirthday) {
      return item.name;
    }
    return '${item.name} (${_nextAge(item)}岁)';
  }

  String _buildSubtitle(AnniversaryItem item) {
    return '${_buildDayStatus(item.date).text}  提醒: ${item.reminderText}';
  }

  Widget _buildBirthdayTitleRow(AnniversaryItem item) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _buildTitle(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_hasReminder(item)) ...[
          const SizedBox(width: 8),
          const Icon(Icons.notifications_active_rounded, size: 18),
        ],
        const SizedBox(width: 8),
        Text('剩余：${_daysUntilNext(item.date)}天'),
      ],
    );
  }

  bool _hasReminder(AnniversaryItem item) {
    return item.reminders.any((option) => option != ReminderOption.none);
  }

  int _daysUntilNext(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _nextOccurrence(date).difference(today).inDays;
  }

  Future<void> _openEditor([AnniversaryItem? item]) async {
    final saved = await showModalBottomSheet<AnniversaryItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AnniversaryEditorSheet(initialItem: item),
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

  Future<void> _openDetail(AnniversaryItem item) async {
    final result = await Navigator.of(context).push<AnniversaryDetailResult>(
      MaterialPageRoute<AnniversaryDetailResult>(
        builder: (context) => AnniversaryDetailPage(item: item),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.deleted) {
      setState(() {
        _anniversaries =
            _anniversaries.where((current) => current.id != item.id).toList();
      });
      await widget.repository.saveAnniversaries(_anniversaries);
      return;
    }

    if (result.item != null) {
      setState(() {
        _anniversaries = _anniversaries
            .map((current) => current.id == result.item!.id ? result.item! : current)
            .toList();
        _anniversaries = _sorted(_anniversaries);
      });
      await widget.repository.saveAnniversaries(_anniversaries);
    }
  }

  List<AnniversaryItem> _sorted(List<AnniversaryItem> source) {
    final copied = List<AnniversaryItem>.from(source);
    copied.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final dayA = _buildDayStatus(a.date);
      final dayB = _buildDayStatus(b.date);
      if (dayA.isUpcoming != dayB.isUpcoming) {
        return dayA.isUpcoming ? -1 : 1;
      }
      return dayA.days.compareTo(dayB.days);
    });
    return copied;
  }

  _DayStatus _buildDayStatus(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisYear = DateTime(today.year, date.month, date.day);
    if (today.isAfter(thisYear)) {
      final passed = today.difference(thisYear).inDays;
      return _DayStatus(days: passed, isUpcoming: false, text: '已过天数$passed');
    }

    final days = thisYear.difference(today).inDays;
    return _DayStatus(days: days, isUpcoming: true, text: '天数$days');
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
}

class _DayStatus {
  const _DayStatus({required this.days, required this.isUpcoming, required this.text});

  final int days;
  final bool isUpcoming;
  final String text;
}
