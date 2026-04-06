import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/library_video.dart';
import '../../../data/models/watch_record.dart';
import '../../player/presentation/player_page.dart';

class FolderLibraryPage extends StatelessWidget {
  const FolderLibraryPage({required this.folderPath, super.key});

  final String folderPath;

  static Route<void> route({required String folderPath}) {
    return MaterialPageRoute<void>(
      builder: (_) => FolderLibraryPage(folderPath: folderPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SnozPlayerScope.of(context);
    final folder = controller.libraryFolderForPath(folderPath);
    final videos = controller.videosInFolder(folderPath);
    final title = folder?.folderName ?? path.basename(folderPath);
    final playlist = videos.map((video) => video.videoPath).toList();

    return Scaffold(
      backgroundColor: AppPalette.cream,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
      ),
      body: SafeArea(
        child: videos.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No playable videos found in this folder.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final video = videos[index];
                  final record = controller.recordForPath(video.videoPath);

                  return _FolderVideoTile(
                    index: index,
                    video: video,
                    record: record,
                    onTap: () {
                      Navigator.of(context).push(
                        PlayerPage.route(
                          videoPath: video.videoPath,
                          playlist: playlist,
                          initialIndex: index,
                          playlistTitle: title,
                        ),
                      );
                    },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: videos.length,
              ),
      ),
    );
  }
}

class _FolderVideoTile extends StatelessWidget {
  const _FolderVideoTile({
    required this.index,
    required this.video,
    required this.record,
    required this.onTap,
  });

  final int index;
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppPalette.sky,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppPalette.berry,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.basenameWithoutExtension(video.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progressRecord == null
                          ? 'Tap to play'
                          : 'Resume from ${_formatClock(progressRecord.positionMs)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.play_arrow_rounded,
                color: AppPalette.berry.withValues(alpha: 0.8),
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
