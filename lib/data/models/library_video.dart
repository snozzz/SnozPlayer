import 'package:path/path.dart' as path;

class LibraryVideo {
  const LibraryVideo({
    required this.videoPath,
    required this.title,
    required this.importedAt,
    required this.folderPath,
    required this.folderName,
  });

  final String videoPath;
  final String title;
  final DateTime importedAt;
  final String folderPath;
  final String folderName;

  factory LibraryVideo.fromJson(Map<String, dynamic> json) {
    final videoPath = json['videoPath'] as String? ?? '';
    final derivedFolderPath = videoPath.isEmpty ? '' : path.dirname(videoPath);
    final folderPathValue = json['folderPath'] as String? ?? derivedFolderPath;
    final folderNameValue =
        json['folderName'] as String? ?? path.basename(folderPathValue);

    return LibraryVideo(
      videoPath: videoPath,
      title: json['title'] as String? ?? '',
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      folderPath: folderPathValue,
      folderName: folderNameValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoPath': videoPath,
      'title': title,
      'importedAt': importedAt.toIso8601String(),
      'folderPath': folderPath,
      'folderName': folderName,
    };
  }
}
