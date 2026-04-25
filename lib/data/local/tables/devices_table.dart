part of '../app_database.dart';

class Devices extends Table {
  TextColumn get deviceId => text()();

  TextColumn get platform => text()();

  TextColumn get deviceName => text().nullable()();

  DateTimeColumn get installedAt => dateTime()();

  DateTimeColumn get lastSeenAt => dateTime()();

  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

