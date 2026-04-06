import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../app/app_controller.dart';
import '../../../app/app_scope.dart';
import '../../../app/theme/app_palette.dart';
import '../../../data/models/watch_record.dart';

enum _BoostSide { left, right }

enum _AdjustmentType { brightness, volume }

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
  static const double _horizontalSeekDeadZone = 14;
  static const int _seekIndicatorFadeOutMs = 520;

  VideoPlayerController? _videoController;
  Timer? _saveTimer;
  Timer? _chromeTimer;
  Timer? _adjustmentTimer;
  Timer? _seekIndicatorTimer;
  bool _isInitializing = true;
  bool _isBoosting = false;
  bool _showChrome = true;
  bool _showAdjustmentIndicator = false;
  bool _showSeekIndicator = false;
  double _selectedSpeed = 1.0;
  bool _didKickoff = false;
  double _rippleVerticalFactor = 0.5;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  double _gestureStartDx = 0;
  double _gestureStartBrightness = 0.5;
  double _gestureStartVolume = 0.5;
  double _gestureStartDy = 0;
  Duration _seekPreviewPosition = Duration.zero;
  Duration _seekDelta = Duration.zero;
  Duration _seekStartPosition = Duration.zero;
  _BoostSide _rippleSide = _BoostSide.right;
  _AdjustmentType _adjustmentType = _AdjustmentType.brightness;
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
    unawaited(_primeSystemLevels());
    _initializeVideo();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _adjustmentTimer?.cancel();
    _seekIndicatorTimer?.cancel();
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

  Future<void> _primeSystemLevels() async {
    try {
      VolumeController.instance.showSystemUI = false;
      final brightness = await ScreenBrightness().application;
      final volume = await VolumeController.instance.getVolume();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentBrightness = brightness.clamp(0.0, 1.0);
        _currentVolume = volume.clamp(0.0, 1.0);
      });
    } catch (_) {
      // Keep defaults if platform values are unavailable.
    }
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

  void _showAdjustment(_AdjustmentType type, double value) {
    _adjustmentTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _adjustmentType = type;
      _showAdjustmentIndicator = true;
      if (type == _AdjustmentType.brightness) {
        _currentBrightness = value;
      } else {
        _currentVolume = value;
      }
    });

    _adjustmentTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showAdjustmentIndicator = false;
      });
    });
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

  void _handleVerticalStart(_AdjustmentType type, DragStartDetails details) {
    _gestureStartDy = details.localPosition.dy;
    _gestureStartBrightness = _currentBrightness;
    _gestureStartVolume = _currentVolume;
    _adjustmentTimer?.cancel();
    _adjustmentType = type;
  }

  Future<void> _handleVerticalUpdate(
    _AdjustmentType type,
    DragUpdateDetails details,
    double zoneHeight,
  ) async {
    final availableHeight = zoneHeight <= 0 ? 1.0 : zoneHeight;
    final delta =
        (_gestureStartDy - details.localPosition.dy) / availableHeight;

    if (type == _AdjustmentType.brightness) {
      final nextBrightness = (_gestureStartBrightness + (delta * 1.4)).clamp(
        0.0,
        1.0,
      );
      try {
        await ScreenBrightness().setApplicationScreenBrightness(nextBrightness);
      } catch (_) {
        return;
      }
      _showAdjustment(_AdjustmentType.brightness, nextBrightness);
      return;
    }

    final nextVolume = (_gestureStartVolume + (delta * 1.4)).clamp(0.0, 1.0);
    try {
      await VolumeController.instance.setVolume(nextVolume);
    } catch (_) {
      return;
    }
    _showAdjustment(_AdjustmentType.volume, nextVolume);
  }

  void _handleVerticalEnd() {
    _adjustmentTimer?.cancel();
    _adjustmentTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showAdjustmentIndicator = false;
      });
    });
  }

  void _handleHorizontalStart(DragStartDetails details) {
    final controller = _videoController;
    if (controller == null || _isBoosting) {
      return;
    }

    _chromeTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _gestureStartDx = details.localPosition.dx;
    _seekStartPosition = controller.value.position;
    _seekPreviewPosition = controller.value.position;
    _seekDelta = Duration.zero;

    if (!mounted) {
      return;
    }

    setState(() {
      _showSeekIndicator = false;
    });
  }

  void _handleHorizontalUpdate(
    DragUpdateDetails details,
    double zoneWidth,
    Duration duration,
  ) {
    final controller = _videoController;
    if (controller == null || _isBoosting) {
      return;
    }

    final availableWidth = zoneWidth <= 0 ? 1.0 : zoneWidth;
    final rawDeltaPx = details.localPosition.dx - _gestureStartDx;
    final effectiveDeltaPx = rawDeltaPx.abs() <= _horizontalSeekDeadZone
        ? 0.0
        : rawDeltaPx.sign * (rawDeltaPx.abs() - _horizontalSeekDeadZone);
    final durationMs = duration.inMilliseconds;
    final maxSeekMs = durationMs <= 0
        ? 30000
        : (durationMs * 0.08).round().clamp(45000, 360000);
    final dragProgress = (effectiveDeltaPx.abs() / (availableWidth * 0.72))
        .clamp(0.0, 1.0);
    final curvedProgress = math.pow(dragProgress, 1.18).toDouble();
    final seekStepMs = durationMs >= const Duration(minutes: 40).inMilliseconds
        ? 5000
        : 2000;
    final deltaMs = effectiveDeltaPx == 0
        ? 0
        : ((effectiveDeltaPx.sign * curvedProgress * maxSeekMs) / seekStepMs)
                  .round() *
              seekStepMs;
    final targetMs = (_seekStartPosition.inMilliseconds + deltaMs).clamp(
      0,
      durationMs <= 0 ? 0 : durationMs,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _showSeekIndicator = deltaMs != 0;
      _seekDelta = Duration(milliseconds: deltaMs);
      _seekPreviewPosition = Duration(milliseconds: targetMs);
    });
  }

  Future<void> _handleHorizontalEnd() async {
    final controller = _videoController;
    if (controller == null || _isBoosting) {
      return;
    }

    final target = _seekPreviewPosition;
    if (_showSeekIndicator && target != controller.value.position) {
      await controller.seekTo(target);
    }

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(
      const Duration(milliseconds: _seekIndicatorFadeOutMs),
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _showSeekIndicator = false;
        });
      },
    );

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
          : AnimatedBuilder(
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
                                  onTap: _toggleChrome,
                                  onDoubleTap: _togglePlaybackByGesture,
                                  onLongPressStart: (details) {
                                    _handleBoostStart(
                                      _BoostSide.left,
                                      details.localPosition.dy,
                                      constraints.maxHeight,
                                    );
                                  },
                                  onLongPressEnd: (_) => _handleBoostEnd(),
                                  onVerticalDragStart: (details) {
                                    _handleVerticalStart(
                                      _AdjustmentType.brightness,
                                      details,
                                    );
                                  },
                                  onVerticalDragUpdate: (details) {
                                    _handleVerticalUpdate(
                                      _AdjustmentType.brightness,
                                      details,
                                      constraints.maxHeight,
                                    );
                                  },
                                  onVerticalDragEnd: (_) =>
                                      _handleVerticalEnd(),
                                  onHorizontalDragStart: _handleHorizontalStart,
                                  onHorizontalDragUpdate: (details) {
                                    _handleHorizontalUpdate(
                                      details,
                                      constraints.maxWidth,
                                      value.duration,
                                    );
                                  },
                                  onHorizontalDragEnd: (_) =>
                                      _handleHorizontalEnd(),
                                ),
                              ),
                              Expanded(
                                child: _BoostZone(
                                  onTap: _toggleChrome,
                                  onDoubleTap: _togglePlaybackByGesture,
                                  onLongPressStart: (details) {
                                    _handleBoostStart(
                                      _BoostSide.right,
                                      details.localPosition.dy,
                                      constraints.maxHeight,
                                    );
                                  },
                                  onLongPressEnd: (_) => _handleBoostEnd(),
                                  onVerticalDragStart: (details) {
                                    _handleVerticalStart(
                                      _AdjustmentType.volume,
                                      details,
                                    );
                                  },
                                  onVerticalDragUpdate: (details) {
                                    _handleVerticalUpdate(
                                      _AdjustmentType.volume,
                                      details,
                                      constraints.maxHeight,
                                    );
                                  },
                                  onVerticalDragEnd: (_) =>
                                      _handleVerticalEnd(),
                                  onHorizontalDragStart: _handleHorizontalStart,
                                  onHorizontalDragUpdate: (details) {
                                    _handleHorizontalUpdate(
                                      details,
                                      constraints.maxWidth,
                                      value.duration,
                                    );
                                  },
                                  onHorizontalDragEnd: (_) =>
                                      _handleHorizontalEnd(),
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
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: _AdjustmentIndicator(
                              isVisible: _showAdjustmentIndicator,
                              type: _adjustmentType,
                              value:
                                  _adjustmentType == _AdjustmentType.brightness
                                  ? _currentBrightness
                                  : _currentVolume,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: _SeekIndicator(
                              isVisible: _showSeekIndicator,
                              targetPosition: _seekPreviewPosition,
                              delta: _seekDelta,
                            ),
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
                                                      .withValues(alpha: 0.72),
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
                                    MediaQuery.of(context).padding.bottom + 18,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.42),
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
                                              position: PopupMenuPosition.over,
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
                                                            style:
                                                                const TextStyle(
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
                                                              color: AppPalette
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
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${_formatSpeed(_selectedSpeed)}x',
                                                      style: const TextStyle(
                                                        color: AppPalette.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.expand_more_rounded,
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
                                                inactiveTrackColor: Colors.white
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
    );
  }
}

class _BoostZone extends StatelessWidget {
  const _BoostZone({
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onHorizontalDragStart,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
  });

  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressEndCallback onLongPressEnd;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      onLongPressCancel: () => onLongPressEnd(
        LongPressEndDetails(
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
      ),
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onHorizontalDragStart: onHorizontalDragStart,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      child: const SizedBox.expand(),
    );
  }
}

class _SeekIndicator extends StatelessWidget {
  const _SeekIndicator({
    required this.isVisible,
    required this.targetPosition,
    required this.delta,
  });

  final bool isVisible;
  final Duration targetPosition;
  final Duration delta;

  @override
  Widget build(BuildContext context) {
    final isForward = delta >= Duration.zero;
    final deltaLabel = '${isForward ? '+' : '-'}${_formatDelta(delta)}';
    final arrowIcon = isForward
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;
    final accentColor = isForward ? AppPalette.peach : AppPalette.sky;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isVisible ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isVisible ? 1 : 0.96,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.56),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < 3; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(
                            arrowIcon,
                            size: 22,
                            color: accentColor.withValues(
                              alpha: 0.45 + (index * 0.2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    deltaLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(targetPosition),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppPalette.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          accentColor.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Slide horizontally to seek',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppPalette.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentIndicator extends StatelessWidget {
  const _AdjustmentIndicator({
    required this.isVisible,
    required this.type,
    required this.value,
  });

  final bool isVisible;
  final _AdjustmentType type;
  final double value;

  @override
  Widget build(BuildContext context) {
    final icon = type == _AdjustmentType.brightness
        ? Icons.light_mode_rounded
        : Icons.volume_up_rounded;
    final label = type == _AdjustmentType.brightness ? 'Brightness' : 'Volume';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isVisible ? 1 : 0,
      child: Container(
        width: 136,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppPalette.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: value,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: AppPalette.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppPalette.white),
            ),
          ],
        ),
      ),
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

String _formatDelta(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
