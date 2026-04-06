class LibraryFolderEntry {
  const LibraryFolderEntry({
    required this.folderPath,
    required this.folderName,
    required this.importedAt,
  });

  final String folderPath;
  final String folderName;
  final DateTime importedAt;

  factory LibraryFolderEntry.fromJson(Map<String, dynamic> json) {
    return LibraryFolderEntry(
      folderPath: json['folderPath'] as String? ?? '',
      folderName: json['folderName'] as String? ?? '',
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'folderPath': folderPath,
      'folderName': folderName,
      'importedAt': importedAt.toIso8601String(),
    };
  }
}
