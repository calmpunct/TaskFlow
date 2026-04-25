part of '../app_database.dart';

class Anniversaries extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  DateTimeColumn get date => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  TextColumn get note => text().withDefault(const Constant(''))();

  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  BoolColumn get isBirthday => boolean().withDefault(const Constant(false))();

  TextColumn get remindersJson => text().withDefault(const Constant('[]'))();

  TextColumn get iconType => text().withDefault(const Constant('builtIn'))();

  IntColumn get iconCodePoint => integer().nullable()();

  TextColumn get iconFontFamily => text().nullable()();

  TextColumn get imagePath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

