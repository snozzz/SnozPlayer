import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/watch_record.dart';
import '../../player/presentation/player_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isPicking = false;

  Future<void> _pickVideo() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      final videoPath = result?.files.single.path;
      if (!mounted || videoPath == null || videoPath.isEmpty) {
        return;
      }

      await Navigator.of(context).push(PlayerPage.route(videoPath: videoPath));
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
                        'Import a video from your device, play it with custom speed, '
                        'and resume later right where you stopped.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _isPicking ? null : _pickVideo,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          _isPicking ? 'Opening picker...' : 'Import video',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recently watched',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!controller.isReady)
                  const Center(child: CircularProgressIndicator())
                else if (records.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppPalette.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      'No videos yet. Import one to start building your watch history.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                else
                  ...records.map((record) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LibraryRecordTile(record: record),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryRecordTile extends StatelessWidget {
  const _LibraryRecordTile({required this.record});

  final WatchRecord record;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.of(
            context,
          ).push(PlayerPage.route(videoPath: record.videoPath));
        },
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
