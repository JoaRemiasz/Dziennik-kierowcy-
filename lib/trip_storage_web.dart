import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _storageKey = 'trips';

Future<String?> loadTripsJson() async {
  final prefs = await SharedPreferences.getInstance();

  return prefs.getString(_storageKey);
}

Future<void> saveTripsJson(String json) async {
  final decoded = jsonDecode(json);

  if (decoded is! List) {
    throw const FormatException(
      'Nieprawidłowy format danych tras.',
    );
  }

  final prefs = await SharedPreferences.getInstance();

  final saved = await prefs.setString(
    _storageKey,
    json,
  );

  if (!saved) {
    throw Exception(
      'Przeglądarka nie potwierdziła zapisu tras.',
    );
  }
}
