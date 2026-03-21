class GameSettings {
  final int roundTimeSeconds;
  final int basePoints;
  final int transitionTime;
  final int streakBonus;
  final bool adaptiveDifficulty;
  final String difficulty;
  final String mode;
  final String title;
  final String description;

  const GameSettings({
    this.roundTimeSeconds = 20,
    this.basePoints = 100,
    this.transitionTime = 3,
    this.streakBonus = 0,
    this.adaptiveDifficulty = false,
    this.difficulty = 'medium',
    this.mode = 'solo',
    this.title = '',
    this.description = '',
  });

  factory GameSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GameSettings();
    return GameSettings(
      roundTimeSeconds: _asInt(json['roundTimeSeconds'], fallback: 20),
      basePoints: _asInt(json['basePoints'], fallback: 100),
      transitionTime: _asInt(json['transitionTime'], fallback: 3),
      streakBonus: _asInt(json['streakBonus'], fallback: 0),
      adaptiveDifficulty: json['adaptiveDifficulty'] == true,
      difficulty: (json['difficulty']?.toString().trim().toLowerCase().isNotEmpty ?? false)
          ? json['difficulty'].toString().trim().toLowerCase()
          : 'medium',
      mode: (json['mode']?.toString().trim().toLowerCase().isNotEmpty ?? false)
          ? json['mode'].toString().trim().toLowerCase()
          : 'solo',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'roundTimeSeconds': roundTimeSeconds,
        'basePoints': basePoints,
        'timeBonus': transitionTime,
        'streakBonus': streakBonus,
        'adaptiveDifficulty': adaptiveDifficulty,
        'difficulty': difficulty,
        'mode': mode,
        'title': title,
        'description': description,
      };

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class GamePlayResult {
  final int score;
  final int maxScore;
  final DateTime completedAt;
  final Map<String, dynamic>? evidencePayload;

  GamePlayResult({
    required this.score,
    required this.maxScore,
    DateTime? completedAt,
    this.evidencePayload,
  }) : completedAt = completedAt ?? DateTime.now();
}
