import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_record.dart';

class WatchHistoryRepository {
  WatchHistoryRepository({Future<SharedPreferences> Function()? prefsFactory})
    : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const _recordsKey = 'watch_history_records_v1';

  final Future<SharedPreferences> Function() _prefsFactory;

  Future<List<WatchRecord>> readRecords() async {
    final prefs = await _prefsFactory();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    final records = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(WatchRecord.fromJson)
        .where((record) => record.videoPath.isNotEmpty)
        .toList();

    records.sort((left, right) {
      return right.lastViewedAt.compareTo(left.lastViewedAt);
    });

    return records;
  }

  Future<void> writeRecords(List<WatchRecord> records) async {
    final prefs = await _prefsFactory();
    final payload = records.map((record) => record.toJson()).toList();
    await prefs.setString(_recordsKey, jsonEncode(payload));
  }
}
