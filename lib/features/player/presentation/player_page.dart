import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';

import '../../../app/app_controller.dart';
import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/watch_record.dart';

enum _BoostSide { left, right }

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
  Timer? _chromeTimer;
  bool _isInitializing = true;
  bool _isBoosting = false;
  bool _showChrome = true;
  double _selectedSpeed = 1.0;
  bool _didKickoff = false;
  double _rippleVerticalFactor = 0.5;
  _BoostSide _rippleSide = _BoostSide.right;
  late final SnozPlayerController _appController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didKickoff) {
      return;
    }

    _didKickoff = true;
    _appController = SnozPlayerScope.of(context);
    unawaited(_enterImmersiveMode());
    _initializeVideo();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _saveTimer?.cancel();
    unawaited(_persistProgress());
    unawaited(_restoreSystemUi());
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _enterImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _initializeVideo() async {
    await _appController.ensureVideoImported(widget.videoPath);
    final record = _appController.recordForPath(widget.videoPath);
    final controller = VideoPlayerController.file(File(widget.videoPath));

    await controller.initialize();
    controller.addListener(_handleVideoTick);

    _selectedSpeed = record?.lastSpeed ?? 1.0;
    await controller.setPlaybackSpeed(_selectedSpeed);

    if (record != null && record.positionMs > 0) {
      final duration = controller.value.duration;
      final safeStart = Duration(milliseconds: record.positionMs);
      final maxStart = duration > const Duration(milliseconds: 400)
          ? duration - const Duration(milliseconds: 400)
          : Duration.zero;
      await controller.seekTo(safeStart < maxStart ? safeStart : maxStart);
    }

    await controller.play();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_persistProgress()),
    );
    _scheduleChromeHide();

    if (mounted) {
      setState(() {
        _videoController = controller;
        _isInitializing = false;
      });
    }
  }

  void _handleVideoTick() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    if (_isBoosting) {
      return;
    }

    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _isBoosting) {
        return;
      }

      setState(() {
        _showChrome = false;
      });
    });
  }

  void _showChromeNow() {
    if (!mounted) {
      return;
    }

    setState(() {
      _showChrome = true;
    });
    _scheduleChromeHide();
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

    _showChromeNow();

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _togglePlaybackByGesture() async {
    await _togglePlayback();
    if (!mounted) {
      return;
    }

    setState(() {
      _showChrome = false;
    });
    _scheduleChromeHide();
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

    _showChromeNow();
  }

  Future<void> _handleBoostStart(
    _BoostSide side,
    double localDy,
    double zoneHeight,
  ) async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _chromeTimer?.cancel();
    _isBoosting = true;
    _showChrome = false;
    _rippleSide = side;
    _rippleVerticalFactor = zoneHeight <= 0
        ? 0.5
        : (localDy / zoneHeight).clamp(0.18, 0.82);

    await controller.setPlaybackSpeed(3.0);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleBoostEnd() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _isBoosting = false;
    await controller.setPlaybackSpeed(_selectedSpeed);

    if (mounted) {
      setState(() {});
    }

    _scheduleChromeHide();
  }

  void _toggleChrome() {
    if (_isBoosting) {
      return;
    }

    setState(() {
      _showChrome = !_showChrome;
    });

    if (_showChrome) {
      _scheduleChromeHide();
    } else {
      _chromeTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final title = path.basename(widget.videoPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitializing || controller == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              onDoubleTap: _togglePlaybackByGesture,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final value = controller.value;
                  final durationMs = value.duration.inMilliseconds;
                  final positionMs = value.position.inMilliseconds.clamp(
                    0,
                    durationMs == 0 ? 1 : durationMs,
                  );
                  final playbackRate = _isBoosting ? 3.0 : _selectedSpeed;

                  return ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: value.size.width <= 0
                                  ? MediaQuery.of(context).size.width
                                  : value.size.width,
                              height: value.size.height <= 0
                                  ? MediaQuery.of(context).size.width / (16 / 9)
                                  : value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _BoostZone(
                                    onLongPressStart: (details) {
                                      _handleBoostStart(
                                        _BoostSide.left,
                                        details.localPosition.dy,
                                        constraints.maxHeight,
                                      );
                                    },
                                    onLongPressEnd: (_) => _handleBoostEnd(),
                                  ),
                                ),
                                Expanded(
                                  child: _BoostZone(
                                    onLongPressStart: (details) {
                                      _handleBoostStart(
                                        _BoostSide.right,
                                        details.localPosition.dy,
                                        constraints.maxHeight,
                                      );
                                    },
                                    onLongPressEnd: (_) => _handleBoostEnd(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _BoostRippleOverlay(
                              isVisible: _isBoosting,
                              verticalFactor: _rippleVerticalFactor,
                              side: _rippleSide,
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _showChrome ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_showChrome,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const _TopScrim(),
                                const _BottomScrim(),
                                Positioned(
                                  top: MediaQuery.of(context).padding.top + 12,
                                  left: 12,
                                  right: 12,
                                  child: Row(
                                    children: [
                                      _PlayerIconButton(
                                        icon: Icons.arrow_back_rounded,
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: AppPalette.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Double tap to play or pause',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppPalette.white
                                                        .withValues(
                                                          alpha: 0.72,
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${_formatSpeed(playbackRate)}x',
                                          style: const TextStyle(
                                            color: AppPalette.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom:
                                      MediaQuery.of(context).padding.bottom +
                                      18,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        16,
                                        18,
                                        12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              _PlayerIconButton(
                                                icon: value.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                onPressed: _togglePlayback,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '${_formatDuration(value.position)} / '
                                                  '${_formatDuration(value.duration)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppPalette.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              PopupMenuButton<double>(
                                                initialValue: _selectedSpeed,
                                                onSelected: _setSelectedSpeed,
                                                color: const Color(0xFF26222B),
                                                position:
                                                    PopupMenuPosition.over,
                                                itemBuilder: (context) {
                                                  return [
                                                    for (final speed
                                                        in _speedPresets)
                                                      PopupMenuItem<double>(
                                                        value: speed,
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              '${_formatSpeed(speed)}x',
                                                              style: const TextStyle(
                                                                color:
                                                                    AppPalette
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            if (speed ==
                                                                _selectedSpeed)
                                                              const Icon(
                                                                Icons
                                                                    .check_rounded,
                                                                color:
                                                                    AppPalette
                                                                        .white,
                                                                size: 18,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                  ];
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '${_formatSpeed(_selectedSpeed)}x',
                                                        style: const TextStyle(
                                                          color:
                                                              AppPalette.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        Icons
                                                            .expand_more_rounded,
                                                        size: 18,
                                                        color: AppPalette.white,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                                  overlayShape:
                                                      SliderComponentShape
                                                          .noOverlay,
                                                  thumbColor: AppPalette.white,
                                                  activeTrackColor:
                                                      AppPalette.white,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.18),
                                                  trackHeight: 3,
                                                ),
                                            child: Slider(
                                              value: positionMs.toDouble(),
                                              min: 0,
                                              max: durationMs == 0
                                                  ? 1
                                                  : durationMs.toDouble(),
                                              onChanged: (nextValue) {
                                                _showChromeNow();
                                                controller.seekTo(
                                                  Duration(
                                                    milliseconds: nextValue
                                                        .round(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _BoostZone extends StatelessWidget {
  const _BoostZone({
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressEndCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      onLongPressCancel: () => onLongPressEnd(
        LongPressEndDetails(
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BoostRippleOverlay extends StatelessWidget {
  const _BoostRippleOverlay({
    required this.isVisible,
    required this.verticalFactor,
    required this.side,
  });

  final bool isVisible;
  final double verticalFactor;
  final _BoostSide side;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = side == _BoostSide.left ? 54.0 : null;
    final rightPadding = side == _BoostSide.right ? 54.0 : null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isVisible ? 1 : 0,
      child: Stack(
        children: [
          Positioned(
            left: horizontalPadding,
            right: rightPadding,
            top: MediaQuery.of(context).size.height * verticalFactor - 34,
            child: Align(
              alignment: side == _BoostSide.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: _RipplePulse(isVisible: isVisible),
            ),
          ),
        ],
      ),
    );
  }
}

class _RipplePulse extends StatefulWidget {
  const _RipplePulse({required this.isVisible});

  final bool isVisible;

  @override
  State<_RipplePulse> createState() => _RipplePulseState();
}

class _RipplePulseState extends State<_RipplePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isVisible) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RipplePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isVisible && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final wave = Curves.easeOut.transform(_controller.value);
        return SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final multiplier in [1.0, 0.72, 0.44])
                Container(
                  width: 30 + (wave * 52 * multiplier),
                  height: 30 + (wave * 52 * multiplier),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: (0.1 * multiplier) * (1 - wave),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: (0.18 * multiplier) * (1 - wave),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppPalette.white),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xAA000000), Color(0x00000000)],
            ),
          ),
          child: SizedBox(height: 160, width: double.infinity),
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
            ),
          ),
          child: SizedBox(height: 240, width: double.infinity),
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

String _formatSpeed(double speed) {
  return speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2);
}
