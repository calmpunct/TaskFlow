part of '../app_database.dart';

class Ops extends Table {
  TextColumn get opId => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get action => text()();

  TextColumn get payload => text()();

  IntColumn get baseVersion => integer().nullable()();

  TextColumn get deviceId => text()();

  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get isApplied => boolean().withDefault(const Constant(false))();

  DateTimeColumn get appliedAt => dateTime().nullable()();

  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

