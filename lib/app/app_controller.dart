import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../data/models/library_folder.dart';
import '../data/models/library_video.dart';
import '../data/models/watch_record.dart';
import '../data/storage/watch_history_repository.dart';

class SnozPlayerController extends ChangeNotifier {
  SnozPlayerController({WatchHistoryRepository? repository})
    : _repository = repository ?? WatchHistoryRepository();

  static const _supportedVideoExtensions = {
    '.mp4',
    '.mkv',
    '.mov',
    '.avi',
    '.m4v',
    '.webm',
    '.flv',
    '.wmv',
    '.ts',
    '.m2ts',
    '.3gp',
  };

  final WatchHistoryRepository _repository;

  bool _isReady = false;
  List<WatchRecord> _records = const [];
  List<LibraryVideo> _libraryVideos = const [];

  bool get isReady => _isReady;
  List<WatchRecord> get records => List.unmodifiable(_records);
  List<LibraryVideo> get libraryVideos => List.unmodifiable(_libraryVideos);
  List<LibraryFolder> get libraryFolders {
    final grouped = <String, List<LibraryVideo>>{};

    for (final video in _libraryVideos) {
      grouped.putIfAbsent(video.folderPath, () => []).add(video);
    }

    final folders = grouped.entries.map((entry) {
      final videos = [...entry.value]..sort(_compareLibraryVideos);
      final folderName = videos.isEmpty
          ? path.basename(entry.key)
          : videos.first.folderName;
      return LibraryFolder(
        folderPath: entry.key,
        folderName: folderName,
        videos: videos,
      );
    }).toList();

    folders.sort((left, right) {
      final byName = _compareNaturally(left.folderName, right.folderName);
      if (byName != 0) {
        return byName;
      }

      return _compareNaturally(left.folderPath, right.folderPath);
    });

    return folders;
  }

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
    _libraryVideos.sort(_compareLibraryVideos);
    _isReady = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _records = await _repository.readRecords();
    _libraryVideos = await _repository.readLibraryVideos();
    _libraryVideos.sort(_compareLibraryVideos);
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

  LibraryFolder? libraryFolderForPath(String folderPath) {
    for (final folder in libraryFolders) {
      if (folder.folderPath == folderPath) {
        return folder;
      }
    }

    return null;
  }

  List<LibraryVideo> videosInFolder(String folderPath) {
    final videos = _libraryVideos
        .where((video) => video.folderPath == folderPath)
        .toList();
    videos.sort(_compareLibraryVideos);
    return videos;
  }

  List<String> playlistForPath(String videoPath) {
    final folderPath =
        libraryVideoForPath(videoPath)?.folderPath ?? path.dirname(videoPath);
    final videos = videosInFolder(folderPath);
    if (videos.isEmpty) {
      return [videoPath];
    }

    final playlist = videos.map((video) => video.videoPath).toList();
    return playlist.contains(videoPath) ? playlist : [videoPath, ...playlist];
  }

  int playlistIndexForPath(String videoPath) {
    final playlist = playlistForPath(videoPath);
    final index = playlist.indexOf(videoPath);
    return index == -1 ? 0 : index;
  }

  String folderNameForPath(String videoPath) {
    final folderPath =
        libraryVideoForPath(videoPath)?.folderPath ?? path.dirname(videoPath);
    final folder = libraryFolderForPath(folderPath);
    return folder?.folderName ?? path.basename(folderPath);
  }

  Future<void> importVideos(
    List<String> videoPaths, {
    String? folderPathOverride,
    String? folderNameOverride,
  }) async {
    final nextLibrary = [..._libraryVideos];
    var changed = false;

    for (final videoPath in videoPaths) {
      final normalizedPath = videoPath.trim();
      if (normalizedPath.isEmpty) {
        continue;
      }

      final effectiveFolderPath = folderPathOverride?.trim().isNotEmpty == true
          ? folderPathOverride!.trim()
          : path.dirname(normalizedPath);
      final effectiveFolderName = folderNameOverride?.trim().isNotEmpty == true
          ? folderNameOverride!.trim()
          : path.basename(effectiveFolderPath);

      final existingIndex = nextLibrary.indexWhere(
        (item) => item.videoPath == normalizedPath,
      );
      if (existingIndex != -1) {
        final existingItem = nextLibrary[existingIndex];
        if (existingItem.folderPath != effectiveFolderPath ||
            existingItem.folderName != effectiveFolderName) {
          nextLibrary[existingIndex] = LibraryVideo(
            videoPath: existingItem.videoPath,
            title: existingItem.title,
            importedAt: existingItem.importedAt,
            folderPath: effectiveFolderPath,
            folderName: effectiveFolderName,
          );
          changed = true;
        }
        continue;
      }

      nextLibrary.add(
        LibraryVideo(
          videoPath: normalizedPath,
          title: path.basename(normalizedPath),
          importedAt: DateTime.now(),
          folderPath: effectiveFolderPath,
          folderName: effectiveFolderName,
        ),
      );
      changed = true;
    }

    if (!changed) {
      return;
    }

    nextLibrary.sort(_compareLibraryVideos);

    _libraryVideos = nextLibrary;
    _isReady = true;
    notifyListeners();
    await _repository.writeLibraryVideos(_libraryVideos);
  }

  Future<List<String>> importFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      return const [];
    }

    final videoPaths = <String>[];

    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final filePath = entity.path;
      if (_isSupportedVideoPath(filePath)) {
        videoPaths.add(filePath);
      }
    }

    videoPaths.sort((left, right) {
      return _compareNaturally(path.basename(left), path.basename(right));
    });

    if (videoPaths.isEmpty) {
      return const [];
    }

    await importVideos(
      videoPaths,
      folderPathOverride: folderPath,
      folderNameOverride: path.basename(folderPath),
    );
    return videoPaths;
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

  bool _isSupportedVideoPath(String filePath) {
    return _supportedVideoExtensions.contains(
      path.extension(filePath).toLowerCase(),
    );
  }

  int _compareLibraryVideos(LibraryVideo left, LibraryVideo right) {
    final byFolder = _compareNaturally(left.folderName, right.folderName);
    if (byFolder != 0) {
      return byFolder;
    }

    final byTitle = _compareNaturally(left.title, right.title);
    if (byTitle != 0) {
      return byTitle;
    }

    return _compareNaturally(left.videoPath, right.videoPath);
  }

  int _compareNaturally(String left, String right) {
    final leftParts = RegExp(
      r'\d+|\D+',
    ).allMatches(left).map((item) => item.group(0)!).toList();
    final rightParts = RegExp(
      r'\d+|\D+',
    ).allMatches(right).map((item) => item.group(0)!).toList();
    final partCount = leftParts.length < rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < partCount; index++) {
      final leftPart = leftParts[index];
      final rightPart = rightParts[index];
      final leftNumber = int.tryParse(leftPart);
      final rightNumber = int.tryParse(rightPart);

      if (leftNumber != null && rightNumber != null) {
        final result = leftNumber.compareTo(rightNumber);
        if (result != 0) {
          return result;
        }
        continue;
      }

      final result = leftPart.toLowerCase().compareTo(rightPart.toLowerCase());
      if (result != 0) {
        return result;
      }
    }

    return leftParts.length.compareTo(rightParts.length);
  }
}
