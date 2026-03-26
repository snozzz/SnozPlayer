class LibraryVideo {
  const LibraryVideo({
    required this.videoPath,
    required this.title,
    required this.importedAt,
  });

  final String videoPath;
  final String title;
  final DateTime importedAt;

  factory LibraryVideo.fromJson(Map<String, dynamic> json) {
    return LibraryVideo(
      videoPath: json['videoPath'] as String? ?? '',
      title: json['title'] as String? ?? '',
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoPath': videoPath,
      'title': title,
      'importedAt': importedAt.toIso8601String(),
    };
  }
}
