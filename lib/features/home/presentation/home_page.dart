import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                            'First milestone',
                            style: TextStyle(
                              color: AppPalette.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Pocket cinema, softer edges, faster gestures.',
                          style: textTheme.displaySmall?.copyWith(
                            color: AppPalette.white,
                            fontSize: 34,
                            height: 0.98,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The next build adds local videos, playback speed presets, '
                          'and the hold-for-3x action on both screen edges.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppPalette.white.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.video_library_rounded),
                                label: const Text('Prepare Library'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                color: AppPalette.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: AppPalette.berry,
                              ),
                            ),
                          ],
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
                          subtitle: '0.5x to 2.0x with quick chips',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _FeatureTile(
                          color: AppPalette.sky,
                          icon: Icons.touch_app_rounded,
                          title: 'Hold for 3x',
                          subtitle: 'Press either side to boost',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Continue concept', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppPalette.white.withValues(alpha: 0.84),
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
                                    'A Studio Ghibli vibe.mp4',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppPalette.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Resume from 12:48 at 1.5x',
                                    style: textTheme.bodyMedium,
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
                              child: const Text(
                                '68%',
                                style: TextStyle(
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
                          child: const LinearProgressIndicator(
                            minHeight: 10,
                            value: 0.68,
                            backgroundColor: AppPalette.blush,
                            color: AppPalette.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Roadmap in app', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const _RoadmapCard(
                    title: 'Playback module',
                    subtitle:
                        'Media engine, seek bar, gesture overlays, and speed memory.',
                    accent: AppPalette.coral,
                  ),
                  const SizedBox(height: 12),
                  const _RoadmapCard(
                    title: 'History module',
                    subtitle:
                        'Resume position, recent activity, and last-used speed per video.',
                    accent: AppPalette.berry,
                  ),
                  const SizedBox(height: 12),
                  const _RoadmapCard(
                    title: 'Polish module',
                    subtitle:
                        'Animations, tablet adaptation, icons, and final visual tuning.',
                    accent: AppPalette.sky,
                  ),
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

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
