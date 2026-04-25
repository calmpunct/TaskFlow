# taskflow

一个任务清单与纪念日软件（本地数据库使用 drift + SQLite）。

## 当前功能

- 底部导航：任务、专注、日历、纪念日
- 任务侧边栏分类：今天、明天、最近7天、收集箱、已经完成、垃圾桶、已经放弃
- 任务支持本地记忆（drift + SQLite 持久化）
- 点击任务进入详情编辑：时间、名字、描述、所在位置

## 数据层结构

- `lib/data/local/app_database.dart`: 数据库入口与初始化
- `lib/data/local/tables/`: 表定义（`tasks`、`ops`、`devices`、`sync_states` 等）
- `lib/data/local/daos/`: DAO 层（CRUD、watch、replay）
- `lib/data/task_repository.dart`: Repository 封装（页面调用入口）
- `lib/data/sync/sync_engine.dart`: 同步引擎接口（当前提供 noop 实现）

## 代码生成（drift）

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## 快速运行

```powershell
flutter pub get
flutter run
```

## 运行测试

```powershell
flutter test
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
