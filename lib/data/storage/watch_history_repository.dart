import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_folder_entry.dart';
import '../models/library_video.dart';
import '../models/watch_record.dart';

class WatchHistoryRepository {
  WatchHistoryRepository({Future<SharedPreferences> Function()? prefsFactory})
    : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const _recordsKey = 'watch_history_records_v1';
  static const _libraryKey = 'library_videos_v1';
  static const _foldersKey = 'library_folders_v1';

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

  Future<List<LibraryVideo>> readLibraryVideos() async {
    final prefs = await _prefsFactory();
    final raw = prefs.getString(_libraryKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    final videos = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(LibraryVideo.fromJson)
        .where((video) => video.videoPath.isNotEmpty)
        .toList();

    videos.sort((left, right) {
      return right.importedAt.compareTo(left.importedAt);
    });

    return videos;
  }

  Future<void> writeLibraryVideos(List<LibraryVideo> videos) async {
    final prefs = await _prefsFactory();
    final payload = videos.map((video) => video.toJson()).toList();
    await prefs.setString(_libraryKey, jsonEncode(payload));
  }

  Future<List<LibraryFolderEntry>> readLibraryFolders() async {
    final prefs = await _prefsFactory();
    final raw = prefs.getString(_foldersKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    final folders = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(LibraryFolderEntry.fromJson)
        .where((folder) => folder.folderPath.isNotEmpty)
        .toList();

    folders.sort((left, right) {
      return right.importedAt.compareTo(left.importedAt);
    });

    return folders;
  }

  Future<void> writeLibraryFolders(List<LibraryFolderEntry> folders) async {
    final prefs = await _prefsFactory();
    final payload = folders.map((folder) => folder.toJson()).toList();
    await prefs.setString(_foldersKey, jsonEncode(payload));
  }
}
