import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../data/models/library_video.dart';
import '../data/models/watch_record.dart';
import '../data/storage/watch_history_repository.dart';

class SnozPlayerController extends ChangeNotifier {
  SnozPlayerController({WatchHistoryRepository? repository})
    : _repository = repository ?? WatchHistoryRepository();

  final WatchHistoryRepository _repository;

  bool _isReady = false;
  List<WatchRecord> _records = const [];
  List<LibraryVideo> _libraryVideos = const [];

  bool get isReady => _isReady;
  List<WatchRecord> get records => List.unmodifiable(_records);
  List<LibraryVideo> get libraryVideos => List.unmodifiable(_libraryVideos);

  WatchRecord? recordForPath(String videoPath) {
    for (final record in _records) {
      if (record.videoPath == videoPath) {
        return record;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }

    _records = await _repository.readRecords();
    _libraryVideos = await _repository.readLibraryVideos();
    _isReady = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _records = await _repository.readRecords();
    _libraryVideos = await _repository.readLibraryVideos();
    _isReady = true;
    notifyListeners();
  }

  LibraryVideo? libraryVideoForPath(String videoPath) {
    for (final video in _libraryVideos) {
      if (video.videoPath == videoPath) {
        return video;
      }
    }

    return null;
  }

  Future<void> importVideos(List<String> videoPaths) async {
    final nextLibrary = [..._libraryVideos];
    var changed = false;

    for (final videoPath in videoPaths) {
      final normalizedPath = videoPath.trim();
      if (normalizedPath.isEmpty) {
        continue;
      }

      final exists = nextLibrary.any(
        (item) => item.videoPath == normalizedPath,
      );
      if (exists) {
        continue;
      }

      nextLibrary.add(
        LibraryVideo(
          videoPath: normalizedPath,
          title: path.basename(normalizedPath),
          importedAt: DateTime.now(),
        ),
      );
      changed = true;
    }

    if (!changed) {
      return;
    }

    nextLibrary.sort((left, right) {
      return right.importedAt.compareTo(left.importedAt);
    });

    _libraryVideos = nextLibrary;
    _isReady = true;
    notifyListeners();
    await _repository.writeLibraryVideos(_libraryVideos);
  }

  Future<void> ensureVideoImported(String videoPath) async {
    await importVideos([videoPath]);
  }

  Future<void> saveRecord(WatchRecord record) async {
    final nextRecords = [..._records];
    final existingIndex = nextRecords.indexWhere(
      (item) => item.videoPath == record.videoPath,
    );

    if (existingIndex == -1) {
      nextRecords.add(record);
    } else {
      nextRecords[existingIndex] = record;
    }

    nextRecords.sort((left, right) {
      return right.lastViewedAt.compareTo(left.lastViewedAt);
    });

    _records = nextRecords;
    _isReady = true;
    notifyListeners();
    await ensureVideoImported(record.videoPath);
    await _repository.writeRecords(_records);
  }
}
