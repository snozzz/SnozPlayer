import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/watch_record.dart';
import '../../player/presentation/player_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.onOpenLibrary, super.key});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final controller = SnozPlayerScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final records = controller.records.take(3).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF2E9), Color(0xFFFFF8EE), Color(0xFFFCEFEB)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppPalette.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppPalette.coral,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SnozPlayer', style: textTheme.titleLarge),
                            Text(
                              'Cute controls for long watching sessions.',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: AppPalette.berry,
                            ),
                            SizedBox(width: 6),
                            Text('Beta'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.coral,
                          AppPalette.peach,
                          AppPalette.sky,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1AFF8E7A),
                          blurRadius: 28,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Playback module ready',
                            style: TextStyle(
                              color: AppPalette.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Import a video and bounce between soft UI and sharp playback controls.',
                          style: textTheme.displaySmall?.copyWith(
                            color: AppPalette.white,
                            fontSize: 34,
                            height: 0.98,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose a speed, hold either side to hit 3x, then let go '
                          'to return to your chosen rate.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppPalette.white.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: onOpenLibrary,
                          icon: const Icon(Icons.video_library_rounded),
                          label: const Text('Go to Library'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(
                        child: _FeatureTile(
                          color: AppPalette.mint,
                          icon: Icons.speed_rounded,
                          title: 'Speed presets',
                          subtitle: '0.5x to 2.0x, restored after boost',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _FeatureTile(
                          color: AppPalette.sky,
                          icon: Icons.touch_app_rounded,
                          title: 'Hold for 3x',
                          subtitle: 'Long press left or right to burst ahead',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Continue watching', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppPalette.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Text(
                        'Your watch history will appear here after you import a video.',
                        style: textTheme.bodyLarge,
                      ),
                    )
                  else
                    ...records.map((record) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecentRecordCard(record: record),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppPalette.ink),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.ink.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.record});

  final WatchRecord record;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          final controller = SnozPlayerScope.of(context);
          Navigator.of(context).push(
            PlayerPage.route(
              videoPath: record.videoPath,
              playlist: controller.playlistForPath(record.videoPath),
              initialIndex: controller.playlistIndexForPath(record.videoPath),
              playlistTitle: controller.folderNameForPath(record.videoPath),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppPalette.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resume from ${_formatDuration(record.positionMs)} '
                          'at ${record.lastSpeed}x',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.blush,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(record.progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppPalette.berry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: record.progress,
                  backgroundColor: AppPalette.blush,
                  color: AppPalette.coral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
