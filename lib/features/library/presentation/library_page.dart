import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/library_folder.dart';
import '../../../data/models/library_video.dart';
import '../../../data/models/watch_record.dart';
import '../../player/presentation/player_page.dart';
import 'folder_library_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isPicking = false;

  Future<void> _pickVideos() async {
    if (_isPicking) {
      return;
    }

    final controller = SnozPlayerScope.of(context);

    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      final videoPaths =
          result?.files
              .map((file) => file.path)
              .whereType<String>()
              .where((filePath) => filePath.isNotEmpty)
              .toList() ??
          const [];

      if (!mounted || videoPaths.isEmpty) {
        return;
      }

      await controller.importVideos(videoPaths);

      if (!mounted) {
        return;
      }

      final firstPath = videoPaths.first;
      await Navigator.of(context).push(
        PlayerPage.route(
          videoPath: firstPath,
          playlist: controller.playlistForPath(firstPath),
          initialIndex: controller.playlistIndexForPath(firstPath),
          playlistTitle: controller.folderNameForPath(firstPath),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _pickFolder() async {
    if (_isPicking) {
      return;
    }

    final controller = SnozPlayerScope.of(context);

    setState(() {
      _isPicking = true;
    });

    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (!mounted || folderPath == null || folderPath.isEmpty) {
        return;
      }

      final importedVideoPaths = await controller.importFolder(folderPath);
      if (!mounted) {
        return;
      }

      if (importedVideoPaths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No supported video files in this folder.'),
          ),
        );
        return;
      }

      await Navigator.of(
        context,
      ).push(FolderLibraryPage.route(folderPath: folderPath));
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = SnozPlayerScope.of(context);
    final records = controller.records;
    final libraryFolders = controller.libraryFolders;
    final libraryVideos = controller.libraryVideos;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppPalette.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local video library',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Import a whole folder or a batch of videos, then browse folders with ordered episodes and separate watch progress.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _isPicking ? null : _pickFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(
                              _isPicking
                                  ? 'Opening picker...'
                                  : 'Import folder',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _isPicking ? null : _pickVideos,
                            icon: const Icon(Icons.video_library_rounded),
                            label: const Text('Batch import videos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Folders', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (!controller.isReady)
                  const Center(child: CircularProgressIndicator())
                else if (libraryFolders.isEmpty)
                  _EmptyCard(
                    message:
                        'Import a folder and your episodes will stay grouped here in filename order.',
                  )
                else
                  ...libraryFolders.map((folder) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LibraryFolderTile(
                        folder: folder,
                        recentRecord: _recentRecordForFolder(
                          folder: folder,
                          records: records,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            FolderLibraryPage.route(
                              folderPath: folder.folderPath,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text(
                  'Imported videos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!controller.isReady)
                  const Center(child: CircularProgressIndicator())
                else if (libraryVideos.isEmpty)
                  const _EmptyCard(
                    message:
                        'Imported videos will also stay here for quick access, even before you start watching.',
                  )
                else
                  ...libraryVideos.map((video) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LibraryVideoTile(
                        video: video,
                        record: controller.recordForPath(video.videoPath),
                        onTap: () {
                          Navigator.of(context).push(
                            PlayerPage.route(
                              videoPath: video.videoPath,
                              playlist: controller.playlistForPath(
                                video.videoPath,
                              ),
                              initialIndex: controller.playlistIndexForPath(
                                video.videoPath,
                              ),
                              playlistTitle: controller.folderNameForPath(
                                video.videoPath,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text(
                  'Recently watched',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!controller.isReady)
                  const Center(child: CircularProgressIndicator())
                else if (records.isEmpty)
                  const _EmptyCard(
                    message:
                        'No videos yet. Import a folder or video to start building your watch history.',
                  )
                else
                  ...records.map((record) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LibraryRecordTile(
                        record: record,
                        onTap: () {
                          Navigator.of(context).push(
                            PlayerPage.route(
                              videoPath: record.videoPath,
                              playlist: controller.playlistForPath(
                                record.videoPath,
                              ),
                              initialIndex: controller.playlistIndexForPath(
                                record.videoPath,
                              ),
                              playlistTitle: controller.folderNameForPath(
                                record.videoPath,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  WatchRecord? _recentRecordForFolder({
    required LibraryFolder folder,
    required List<WatchRecord> records,
  }) {
    final folderPaths = folder.videos.map((video) => video.videoPath).toSet();
    for (final record in records) {
      if (folderPaths.contains(record.videoPath)) {
        return record;
      }
    }

    return null;
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppPalette.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _LibraryFolderTile extends StatelessWidget {
  const _LibraryFolderTile({
    required this.folder,
    required this.recentRecord,
    required this.onTap,
  });

  final LibraryFolder folder;
  final WatchRecord? recentRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.mint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  size: 34,
                  color: AppPalette.berry,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${folder.videoCount} episodes',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recentRecord == null
                          ? 'Tap to view folder'
                          : 'Recent: ${recentRecord!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.berry),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryVideoTile extends StatelessWidget {
  const _LibraryVideoTile({
    required this.video,
    required this.record,
    required this.onTap,
  });

  final LibraryVideo video;
  final WatchRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressRecord = record;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.sky,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 34,
                  color: AppPalette.berry,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progressRecord == null
                          ? 'Ready to watch'
                          : 'Resume from ${_formatClock(progressRecord.positionMs)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: record?.progress ?? 0,
                        backgroundColor: AppPalette.blush,
                        color: AppPalette.coral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    progressRecord == null
                        ? 'New'
                        : '${(progressRecord.progress * 100).round()}%',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppPalette.berry),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path
                            .extension(video.videoPath)
                            .replaceFirst('.', '')
                            .isEmpty
                        ? 'video'
                        : path.extension(video.videoPath).replaceFirst('.', ''),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryRecordTile extends StatelessWidget {
  const _LibraryRecordTile({required this.record, required this.onTap});

  final WatchRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.blush,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 34,
                  color: AppPalette.berry,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last speed ${record.lastSpeed}x',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: record.progress,
                        backgroundColor: AppPalette.blush,
                        color: AppPalette.coral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(record.progress * 100).round()}%',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppPalette.berry),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatClock(record.positionMs),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatClock(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
