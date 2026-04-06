import 'library_video.dart';

class LibraryFolder {
  const LibraryFolder({
    required this.folderPath,
    required this.folderName,
    required this.videos,
    required this.importedAt,
  });

  final String folderPath;
  final String folderName;
  final List<LibraryVideo> videos;
  final DateTime importedAt;

  int get videoCount => videos.length;
}
