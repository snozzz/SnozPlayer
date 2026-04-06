import 'library_video.dart';

class LibraryFolder {
  const LibraryFolder({
    required this.folderPath,
    required this.folderName,
    required this.videos,
  });

  final String folderPath;
  final String folderName;
  final List<LibraryVideo> videos;

  int get videoCount => videos.length;
}
