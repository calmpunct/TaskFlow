part of '../app_database.dart';

@DriftAccessor(tables: [Anniversaries])
class AnniversaryDao extends DatabaseAccessor<AppDatabase>
    with _$AnniversaryDaoMixin {
  AnniversaryDao(super.db);

  Future<List<Anniversary>> getAllAnniversaries() {
    return (select(anniversaries)
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .get();
  }

  Future<void> replaceAll(List<AnniversariesCompanion> entries) async {
    await transaction(() async {
      await delete(anniversaries).go();
      await batch((batch) {
        batch.insertAll(anniversaries, entries);
      });
    });
  }
}

