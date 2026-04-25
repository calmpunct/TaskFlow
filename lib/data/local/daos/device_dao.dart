part of '../app_database.dart';

@DriftAccessor(tables: [Devices])
class DeviceDao extends DatabaseAccessor<AppDatabase> with _$DeviceDaoMixin {
  DeviceDao(super.db);

  Future<void> upsertDevice(DevicesCompanion entry) async {
    await into(devices).insertOnConflictUpdate(entry);
  }

  Future<void> setCurrentDevice(String deviceIdValue) async {
    await transaction(() async {
      await update(devices).write(const DevicesCompanion(isCurrent: Value(false)));
      await (update(devices)..where((d) => d.deviceId.equals(deviceIdValue))).write(
        DevicesCompanion(
          isCurrent: const Value(true),
          lastSeenAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<Device?> getCurrentDevice() {
    return (select(devices)..where((d) => d.isCurrent.equals(true))).getSingleOrNull();
  }
}

