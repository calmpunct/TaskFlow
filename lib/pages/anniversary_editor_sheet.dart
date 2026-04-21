import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taskflow/models/anniversary_item.dart';

class AnniversaryEditorSheet extends StatefulWidget {
  const AnniversaryEditorSheet({super.key, this.initialItem});

  final AnniversaryItem? initialItem;

  @override
  State<AnniversaryEditorSheet> createState() => _AnniversaryEditorSheetState();
}

class _AnniversaryEditorSheetState extends State<AnniversaryEditorSheet> {
  static const List<IconData> _presetIcons = <IconData>[
    Icons.favorite_rounded,
    Icons.cake_rounded,
    Icons.celebration_rounded,
    Icons.flight_takeoff_rounded,
    Icons.house_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
    Icons.pets_rounded,
    Icons.spa_rounded,
    Icons.flag_rounded,
    Icons.favorite_border_rounded,
    Icons.star_rounded,
  ];

  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late bool _isPinned;
  late ReminderOption _reminder;
  late AnniversaryIconType _iconType;
  late IconData _selectedIcon;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _selectedDate = initial?.date ?? DateTime.now();
    _isPinned = initial?.isPinned ?? false;
    _reminder = initial?.reminder ?? ReminderOption.none;
    _iconType = initial?.iconType ?? AnniversaryIconType.builtIn;
    _selectedIcon = initial?.builtInIcon ?? Icons.flag_rounded;
    _imagePath = initial?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialItem == null ? '添加纪念日' : '编辑纪念日',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名字',
                  hintText: '例如：结婚纪念日',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('日期'),
                subtitle: Text(_formatDate(_selectedDate)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('选择'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '补充纪念日相关信息',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('置顶'),
                value: _isPinned,
                onChanged: (value) {
                  setState(() {
                    _isPinned = value;
                  });
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('提醒'),
                subtitle: Text(_reminder.label),
                onTap: _pickReminder,
              ),
              const SizedBox(height: 8),
              Text(
                '图标',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AnniversaryIconType>(
                segments: const [
                  ButtonSegment<AnniversaryIconType>(
                    value: AnniversaryIconType.builtIn,
                    label: Text('内置图标'),
                    icon: Icon(Icons.apps_rounded),
                  ),
                  ButtonSegment<AnniversaryIconType>(
                    value: AnniversaryIconType.image,
                    label: Text('自选图片'),
                    icon: Icon(Icons.image_rounded),
                  ),
                ],
                selected: <AnniversaryIconType>{_iconType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _iconType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_iconType == AnniversaryIconType.builtIn) _buildIconGrid(),
              if (_iconType == AnniversaryIconType.image) _buildImagePicker(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('保存纪念日'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetIcons.map((icon) {
        final selected =
            _selectedIcon.codePoint == icon.codePoint && _selectedIcon.fontFamily == icon.fontFamily;
        return ChoiceChip(
          label: Icon(icon),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedIcon = icon;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildImagePicker() {
    final imagePath = _imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imagePath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded),
                );
              },
            ),
          )
        else
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_rounded),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('选择图片'),
            ),
            TextButton(
              onPressed: imagePath == null
                  ? null
                  : () {
                      setState(() {
                        _imagePath = null;
                      });
                    },
              child: const Text('清除'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickReminder() async {
    final picked = await showModalBottomSheet<ReminderOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: ReminderOption.values
                .map(
                  (option) => ListTile(
                    title: Text(option.label),
                    trailing: option == _reminder
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _reminder = picked;
    });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) {
      return;
    }

    setState(() {
      _imagePath = file.path;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名字不能为空')),
      );
      return;
    }

    if (_iconType == AnniversaryIconType.image && (_imagePath == null || _imagePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择图片或切换为内置图标')),
      );
      return;
    }

    final now = DateTime.now();
    final initial = widget.initialItem;
    final saved = (initial ??
            AnniversaryItem(
              id: now.microsecondsSinceEpoch.toString(),
              name: name,
              date: _selectedDate,
              createdAt: now,
            ))
        .copyWith(
          name: name,
          date: _selectedDate,
          note: _noteController.text.trim(),
          isPinned: _isPinned,
          reminder: _reminder,
          iconType: _iconType,
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          imagePath: _iconType == AnniversaryIconType.image ? _imagePath : null,
          clearImage: _iconType != AnniversaryIconType.image,
        );

    Navigator.of(context).pop(saved);
  }

  String _formatDate(DateTime value) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }
}

