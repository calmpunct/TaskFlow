import 'dart:convert';

enum TaskStatus { inbox, completed, trashed, abandoned }

enum TaskFilter {
  today,
  tomorrow,
  next7Days,
  inbox,
  completed,
  trashed,
  abandoned,
}

extension TaskFilterView on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.today:
        return '今天';
      case TaskFilter.tomorrow:
        return '明天';
      case TaskFilter.next7Days:
        return '最近7天';
      case TaskFilter.inbox:
        return '收集箱';
      case TaskFilter.completed:
        return '已经完成';
      case TaskFilter.trashed:
        return '垃圾桶';
      case TaskFilter.abandoned:
        return '已经放弃';
    }
  }
}

extension TaskStatusView on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.inbox:
        return '待办';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.trashed:
        return '已删除';
      case TaskStatus.abandoned:
        return '已放弃';
    }
  }
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description = '',
    this.listName = '收集箱',
    this.dueAt,
    this.status = TaskStatus.inbox,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String description;
  final String listName;
  final DateTime? dueAt;
  final TaskStatus status;

  TaskItem copyWith({
    String? id,
    DateTime? createdAt,
    String? title,
    String? description,
    String? listName,
    DateTime? dueAt,
    TaskStatus? status,
    bool clearDueAt = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      listName: listName ?? this.listName,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'title': title,
      'description': description,
      'listName': listName,
      'dueAt': dueAt?.toIso8601String(),
      'status': status.name,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      listName: (json['listName'] as String?) ?? '收集箱',
      dueAt: json['dueAt'] == null
          ? null
          : DateTime.parse(json['dueAt'] as String),
      status: TaskStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TaskStatus.inbox,
      ),
    );
  }

  static String encodeList(List<TaskItem> tasks) {
    final jsonList = tasks.map((task) => task.toJson()).toList();
    return jsonEncode(jsonList);
  }

  static List<TaskItem> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 获取距离截止日期的天数
  /// Returns: positive days if upcoming, negative days if overdue, null if no dueAt
  int? get countdownDays {
    if (dueAt == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(dueAt!.year, dueAt!.month, dueAt!.day);

    return dueDate.difference(today).inDays;
  }

  /// 获取倒计时显示文本
  /// Returns a human-readable countdown string
  String? get countdownText {
    final days = countdownDays;
    if (days == null) return null;

    if (days < 0) {
      return '逾期 ${days.abs()} 天';
    } else if (days == 0) {
      return '今天';
    } else if (days == 1) {
      return '明天';
    } else {
      return '倒数 $days 天';
    }
  }

  /// 判断是否已过期
  bool get isOverdue {
    if (status == TaskStatus.completed || status == TaskStatus.trashed || status == TaskStatus.abandoned) {
      return false;
    }
    final days = countdownDays;
    return days != null && days < 0;
  }

  /// 判断是否即将到期（3天内）
  bool get isDuesoon {
    if (status != TaskStatus.inbox) {
      return false;
    }
    final days = countdownDays;
    return days != null && days >= 0 && days <= 3;
  }
}

