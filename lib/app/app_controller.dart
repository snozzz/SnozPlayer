import 'package:flutter/foundation.dart';

import '../data/models/watch_record.dart';
import '../data/storage/watch_history_repository.dart';

class SnozPlayerController extends ChangeNotifier {
  SnozPlayerController({WatchHistoryRepository? repository})
    : _repository = repository ?? WatchHistoryRepository();

  final WatchHistoryRepository _repository;

  bool _isReady = false;
  List<WatchRecord> _records = const [];

  bool get isReady => _isReady;
  List<WatchRecord> get records => List.unmodifiable(_records);

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
    _isReady = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _records = await _repository.readRecords();
    _isReady = true;
    notifyListeners();
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
    await _repository.writeRecords(_records);
  }
}
