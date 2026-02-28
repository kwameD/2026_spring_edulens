class GamePlayResult {
  /// Number of correct items (raw)
  final int score;

  /// Maximum possible correct items (raw)
  final int maxScore;

  /// Optional point-based scoring (e.g., time bonus, streak bonus).
  /// If not used, these will be null.
  final int? pointsEarned;
  final int? pointsMax;

  /// Optional metadata for classroom-style formats (e.g., TEAM mode)
  final Map<String, dynamic>? meta;

  final DateTime completedAt;

  GamePlayResult({
    required this.score,
    required this.maxScore,
    this.pointsEarned,
    this.pointsMax,
    this.meta,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();
}
