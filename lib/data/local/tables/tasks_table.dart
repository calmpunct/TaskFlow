part of '../app_database.dart';

class Tasks extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get listName => text().withDefault(const Constant('收集箱'))();

  DateTimeColumn get dueAt => dateTime().nullable()();

  TextColumn get status => text().withDefault(const Constant('inbox'))();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get lastOpId => text().nullable()();

  TextColumn get lastDeviceId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

