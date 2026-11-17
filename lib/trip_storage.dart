import 'trip_storage_stub.dart'
    if (dart.library.html) 'trip_storage_web.dart'
    if (dart.library.io) 'trip_storage_mobile.dart' as platform;

Future<String?> loadTripsJson() {
  return platform.loadTripsJson();
}

Future<void> saveTripsJson(String json) {
  return platform.saveTripsJson(json);
}
