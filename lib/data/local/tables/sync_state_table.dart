part of '../app_database.dart';

class SyncStates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get scope => text().withDefault(const Constant('global'))();

  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  DateTimeColumn get lastPulledOpAt => dateTime().nullable()();

  DateTimeColumn get lastPushedOpAt => dateTime().nullable()();

  TextColumn get syncCursor => text().nullable()();

  BoolColumn get isSyncing => boolean().withDefault(const Constant(false))();

  TextColumn get lastError => text().nullable()();
}

