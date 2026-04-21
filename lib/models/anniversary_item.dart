import 'dart:convert';

import 'package:flutter/material.dart';

enum AnniversaryIconType { builtIn, image }

enum ReminderOption { none, sameDay, oneDay, threeDays, oneWeek, oneMonth }

extension ReminderOptionView on ReminderOption {
  String get label {
    switch (this) {
      case ReminderOption.none:
        return '无';
      case ReminderOption.sameDay:
        return '当天';
      case ReminderOption.oneDay:
        return '一天';
      case ReminderOption.threeDays:
        return '3天';
      case ReminderOption.oneWeek:
        return '1周';
      case ReminderOption.oneMonth:
        return '一个月';
    }
  }
}

class AnniversaryItem {
  static const List<IconData> _builtInIconPool = <IconData>[
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

  AnniversaryItem({
    required this.id,
    required this.name,
    required this.date,
    required this.createdAt,
    this.note = '',
    this.isPinned = false,
    this.isBirthday = false,
    this.reminders = const <ReminderOption>[ReminderOption.none],
    this.iconType = AnniversaryIconType.builtIn,
    this.iconCodePoint,
    this.iconFontFamily,
    this.imagePath,
  });

  final String id;
  final String name;
  final DateTime date;
  final DateTime createdAt;
  final String note;
  final bool isPinned;
  final bool isBirthday;
  final List<ReminderOption> reminders;
  final AnniversaryIconType iconType;
  final int? iconCodePoint;
  final String? iconFontFamily;
  final String? imagePath;

  String get reminderText {
    if (reminders.isEmpty) {
      return ReminderOption.none.label;
    }
    return reminders.map((option) => option.label).join('、');
  }

  IconData get builtInIcon {
    final codePoint = iconCodePoint;
    final fontFamily = iconFontFamily;
    if (codePoint == null) {
      return Icons.flag_rounded;
    }

    for (final icon in _builtInIconPool) {
      if (icon.codePoint == codePoint &&
          (fontFamily == null || icon.fontFamily == fontFamily)) {
        return icon;
      }
    }
    return Icons.flag_rounded;
  }

  AnniversaryItem copyWith({
    String? id,
    String? name,
    DateTime? date,
    DateTime? createdAt,
    String? note,
    bool? isPinned,
    bool? isBirthday,
    List<ReminderOption>? reminders,
    AnniversaryIconType? iconType,
    int? iconCodePoint,
    String? iconFontFamily,
    String? imagePath,
    bool clearImage = false,
  }) {
    return AnniversaryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      isPinned: isPinned ?? this.isPinned,
      isBirthday: isBirthday ?? this.isBirthday,
      reminders: reminders ?? this.reminders,
      iconType: iconType ?? this.iconType,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'isPinned': isPinned,
      'isBirthday': isBirthday,
      'reminders': reminders.map((option) => option.name).toList(),
      'iconType': iconType.name,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'imagePath': imagePath,
    };
  }

  factory AnniversaryItem.fromJson(Map<String, dynamic> json) {
    final reminderRaw = json['reminders'];
    final reminderList = reminderRaw is List
        ? reminderRaw
            .map((value) => ReminderOption.values.firstWhere(
                  (option) => option.name == value,
                  orElse: () => ReminderOption.none,
                ))
            .toList()
        : <ReminderOption>[];
    if (reminderList.isEmpty) {
      reminderList.add(
        ReminderOption.values.firstWhere(
          (value) => value.name == json['reminder'],
          orElse: () => ReminderOption.none,
        ),
      );
    }

    return AnniversaryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      note: (json['note'] as String?) ?? '',
      isPinned: (json['isPinned'] as bool?) ?? false,
      isBirthday: (json['isBirthday'] as bool?) ?? false,
      reminders: reminderList.toSet().toList(),
      iconType: AnniversaryIconType.values.firstWhere(
        (value) => value.name == json['iconType'],
        orElse: () => AnniversaryIconType.builtIn,
      ),
      iconCodePoint: json['iconCodePoint'] as int?,
      iconFontFamily: json['iconFontFamily'] as String?,
      imagePath: json['imagePath'] as String?,
    );
  }

  static String encodeList(List<AnniversaryItem> items) {
    final jsonList = items.map((item) => item.toJson()).toList();
    return jsonEncode(jsonList);
  }

  static List<AnniversaryItem> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => AnniversaryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

