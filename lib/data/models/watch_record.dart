class WatchRecord {
  const WatchRecord({
    required this.videoPath,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.lastSpeed,
    required this.lastViewedAt,
  });

  final String videoPath;
  final String title;
  final int positionMs;
  final int durationMs;
  final double lastSpeed;
  final DateTime lastViewedAt;

  double get progress {
    if (durationMs <= 0) {
      return 0;
    }

    return (positionMs / durationMs).clamp(0, 1);
  }

  WatchRecord copyWith({
    String? videoPath,
    String? title,
    int? positionMs,
    int? durationMs,
    double? lastSpeed,
    DateTime? lastViewedAt,
  }) {
    return WatchRecord(
      videoPath: videoPath ?? this.videoPath,
      title: title ?? this.title,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastSpeed: lastSpeed ?? this.lastSpeed,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
    );
  }

  factory WatchRecord.fromJson(Map<String, dynamic> json) {
    return WatchRecord(
      videoPath: json['videoPath'] as String? ?? '',
      title: json['title'] as String? ?? '',
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      lastSpeed: (json['lastSpeed'] as num?)?.toDouble() ?? 1,
      lastViewedAt:
          DateTime.tryParse(json['lastViewedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoPath': videoPath,
      'title': title,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'lastSpeed': lastSpeed,
      'lastViewedAt': lastViewedAt.toIso8601String(),
    };
  }
}
