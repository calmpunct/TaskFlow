part of '../app_database.dart';

@DriftAccessor(tables: [CustomLists])
class CustomListDao extends DatabaseAccessor<AppDatabase>
    with _$CustomListDaoMixin {
  CustomListDao(super.db);

  Future<List<String>> getAllNames() async {
    final rows = await (select(customLists)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    return rows.map((row) => row.name).toList();
  }

  Future<void> replaceAll(List<String> names) async {
    final uniqueSorted = names.toSet().toList()..sort();
    await transaction(() async {
      await delete(customLists).go();
      await batch((batch) {
        batch.insertAll(
          customLists,
          uniqueSorted
              .map((name) => CustomListsCompanion(name: Value(name)))
              .toList(),
        );
      });
    });
  }
}

