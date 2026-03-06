class GamePlayResult {
  final int score;
  final int maxScore;
  final int earnedPoints;
  final DateTime completedAt;

  GamePlayResult({
    required this.score,
    required this.maxScore,
    this.earnedPoints = 0,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();
}
