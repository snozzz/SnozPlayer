import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';

import '../../../app/app_controller.dart';
import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/watch_record.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({required this.videoPath, super.key});

  final String videoPath;

  static Route<void> route({required String videoPath}) {
    return MaterialPageRoute<void>(
      builder: (_) => PlayerPage(videoPath: videoPath),
    );
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const _speedPresets = [0.5, 1.0, 1.25, 1.5, 2.0];

  VideoPlayerController? _videoController;
  Timer? _saveTimer;
  bool _isInitializing = true;
  bool _isBoosting = false;
  double _selectedSpeed = 1.0;
  bool _didKickoff = false;
  late final SnozPlayerController _appController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didKickoff) {
      return;
    }

    _didKickoff = true;
    _appController = SnozPlayerScope.of(context);
    _initializeVideo();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persistProgress());
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final record = _appController.recordForPath(widget.videoPath);
    final controller = VideoPlayerController.file(File(widget.videoPath));

    await controller.initialize();

    _selectedSpeed = record?.lastSpeed ?? 1.0;
    await controller.setPlaybackSpeed(_selectedSpeed);

    if (record != null && record.positionMs > 0) {
      final maxStart =
          controller.value.duration - const Duration(milliseconds: 400);
      final safeStart = Duration(milliseconds: record.positionMs);
      await controller.seekTo(safeStart < maxStart ? safeStart : maxStart);
    }

    await controller.play();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_persistProgress()),
    );

    if (mounted) {
      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    }
  }

  Future<void> _persistProgress() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;
    final rawPosition = controller.value.position;
    final reachedEnd =
        duration > Duration.zero && rawPosition >= duration * 0.98;
    final safePosition = reachedEnd ? Duration.zero : rawPosition;

    final record = WatchRecord(
      videoPath: widget.videoPath,
      title: path.basename(widget.videoPath),
      positionMs: safePosition.inMilliseconds,
      durationMs: duration.inMilliseconds,
      lastSpeed: _selectedSpeed,
      lastViewedAt: DateTime.now(),
    );

    await _appController.saveRecord(record);
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setSelectedSpeed(double speed) async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _selectedSpeed = speed;
    if (!_isBoosting) {
      await controller.setPlaybackSpeed(speed);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setBoosting(bool isBoosting) async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _isBoosting = isBoosting;
    await controller.setPlaybackSpeed(isBoosting ? 3.0 : _selectedSpeed);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final title = path.basename(widget.videoPath);

    return Scaffold(
      backgroundColor: const Color(0xFF19161F),
      body: SafeArea(
        child: _isInitializing || controller == null
            ? const Center(child: CircularProgressIndicator())
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final value = controller.value;
                  final playbackRate = _isBoosting ? 3.0 : _selectedSpeed;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
                        child: Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: AppPalette.white),
                                  ),
                                  Text(
                                    'Long press left or right for 3x boost',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppPalette.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
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
                                color: AppPalette.berry.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${playbackRate.toStringAsFixed(playbackRate == playbackRate.roundToDouble() ? 0 : 2)}x',
                                style: const TextStyle(
                                  color: AppPalette.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: AspectRatio(
                              aspectRatio: value.aspectRatio == 0
                                  ? 16 / 9
                                  : value.aspectRatio,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(
                                      color: Colors.black,
                                      child: VideoPlayer(controller),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _BoostZone(
                                            alignment: Alignment.centerLeft,
                                            label: 'Hold 3x',
                                            onLongPressStart: () =>
                                                _setBoosting(true),
                                            onLongPressEnd: () =>
                                                _setBoosting(false),
                                          ),
                                        ),
                                        Expanded(
                                          child: _BoostZone(
                                            alignment: Alignment.centerRight,
                                            label: 'Hold 3x',
                                            onLongPressStart: () =>
                                                _setBoosting(true),
                                            onLongPressEnd: () =>
                                                _setBoosting(false),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      left: 20,
                                      right: 20,
                                      bottom: 20,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        opacity: _isBoosting ? 1 : 0,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppPalette.berry
                                                  .withValues(alpha: 0.82),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '3x boost active',
                                              style: TextStyle(
                                                color: AppPalette.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppPalette.white,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton.filled(
                                  onPressed: _togglePlayback,
                                  icon: Icon(
                                    value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${_formatDuration(value.position)} / '
                                    '${_formatDuration(value.duration)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: AppPalette.ink),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Slider(
                              value: value.duration.inMilliseconds == 0
                                  ? 0
                                  : value.position.inMilliseconds
                                        .clamp(0, value.duration.inMilliseconds)
                                        .toDouble(),
                              min: 0,
                              max: value.duration.inMilliseconds == 0
                                  ? 1
                                  : value.duration.inMilliseconds.toDouble(),
                              onChanged: (nextValue) {
                                controller.seekTo(
                                  Duration(milliseconds: nextValue.round()),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Playback speed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final speed in _speedPresets)
                                  ChoiceChip(
                                    label: Text('${speed}x'),
                                    selected: speed == _selectedSpeed,
                                    onSelected: (_) => _setSelectedSpeed(speed),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _BoostZone extends StatelessWidget {
  const _BoostZone({
    required this.alignment,
    required this.label,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final Alignment alignment;
  final String label;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      onLongPressCancel: onLongPressEnd,
      child: Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
