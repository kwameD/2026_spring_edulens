import 'dart:async';

import 'package:flutter/material.dart';

import 'game_result.dart';

/// QuizGame supports timed rounds, point-based scoring, and (optional) adaptive
/// difficulty selection when questions include a "difficulty" field.
class QuizGame extends StatefulWidget {
  /// Questions format (per item):
  /// {
  ///   "question": "...",
  ///   "options": ["A","B","C","D"],
  ///   "answer": 0,
  ///   // optional:
  ///   "difficulty": "easy" | "medium" | "hard"
  /// }
  final List<Map<String, dynamic>> questions;

  /// Optional gameplay settings (passed from assigned game payload):
  /// {
  ///   "questionCount": 10,
  ///   "timedRoundSeconds": 20,         // per-question timer; 0 disables
  ///   "difficulty": "Medium",          // starting difficulty label
  ///   "adaptiveDifficulty": true,      // if true, adjusts difficulty based on performance
  ///   "mode": "SOLO" | "TEAM",         // informational; UX can show it
  /// }
  final Map<String, dynamic>? settings;

  final void Function(GamePlayResult result) onComplete;
  final bool previewMode;

  const QuizGame({
    super.key,
    required this.questions,
    required this.onComplete,
    this.previewMode = false,
    this.settings,
  });

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  int currentIndex = 0;

  // raw scoring
  int correctCount = 0;

  // point scoring
  int points = 0;
  int streak = 0;

  bool showResult = false;
  bool? wasCorrect;
  List<Map<String, String>> userAnswers = [];
  String? previewSelected;
  bool _completionReported = false;

  // timed rounds
  Timer? _timer;
  int _remainingSeconds = 0;

  // difficulty adjustment
  String _currentDifficulty = 'medium';
  int _consecutiveCorrect = 0;
  int _consecutiveWrong = 0;

  List<Map<String, dynamic>> _activeQuestions = const [];

  int get _questionCount {
    final raw = widget.settings?['questionCount'];
    if (raw is int && raw > 0) return raw;
    return 5;
  }

  int get _timedRoundSeconds {
    final raw = widget.settings?['timedRoundSeconds'];
    if (raw is int && raw >= 0) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  bool get _adaptiveDifficulty {
    final raw = widget.settings?['adaptiveDifficulty'];
    if (raw is bool) return raw;
    return false;
  }

  String get _mode {
    final raw = widget.settings?['mode'];
    if (raw is String && raw.isNotEmpty) return raw.toUpperCase();
    return 'SOLO';
  }

  @override
  void initState() {
    super.initState();
    _currentDifficulty = _normalizeDifficulty(widget.settings?['difficulty']);
    _activeQuestions = _selectQuestions();
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _normalizeDifficulty(dynamic value) {
    final s = (value ?? '').toString().trim().toLowerCase();
    if (s.startsWith('e')) return 'easy';
    if (s.startsWith('h')) return 'hard';
    return 'medium';
  }

  List<Map<String, dynamic>> _selectQuestions() {
    // If adaptive difficulty is enabled and questions include difficulty labels,
    // we pick from the current difficulty bucket first.
    final all = List<Map<String, dynamic>>.from(widget.questions);
    if (all.isEmpty) return const [];

    // Ensure "difficulty" is normalized if present
    for (final q in all) {
      if (q.containsKey('difficulty')) {
        q['difficulty'] = _normalizeDifficulty(q['difficulty']);
      }
    }

    // If no difficulty labels exist, just take the first N
    final hasDiff =
        all.any((q) => (q['difficulty'] ?? '').toString().isNotEmpty);
    if (!hasDiff) {
      return all.take(_questionCount).toList();
    }

    // Build buckets
    final easy = all.where((q) => q['difficulty'] == 'easy').toList();
    final med = all.where((q) => q['difficulty'] == 'medium').toList();
    final hard = all.where((q) => q['difficulty'] == 'hard').toList();

    // For non-adaptive, prefer selected difficulty but backfill if needed
    if (!_adaptiveDifficulty) {
      final primary = _bucketForDifficulty(easy, med, hard, _currentDifficulty);
      final taken = <Map<String, dynamic>>[];
      taken.addAll(primary.take(_questionCount));
      if (taken.length < _questionCount) {
        final remainder = all.where((q) => !taken.contains(q)).toList();
        taken.addAll(remainder.take(_questionCount - taken.length));
      }
      return taken;
    }

    // Adaptive: start with a mixed set so we can adjust without re-calling LLM.
    // Take ~40% from start difficulty, 30% from adjacent, 30% from others (backfill).
    final taken = <Map<String, dynamic>>[];
    final startBucket =
        _bucketForDifficulty(easy, med, hard, _currentDifficulty);
    taken.addAll(startBucket.take((_questionCount * 0.4).ceil()));

    final adjacent = _currentDifficulty == 'medium'
        ? [...easy, ...hard]
        : (_currentDifficulty == 'easy' ? med : med);
    taken.addAll(adjacent
        .where((q) => !taken.contains(q))
        .take((_questionCount * 0.3).ceil()));

    final remainder = all.where((q) => !taken.contains(q)).toList();
    taken.addAll(remainder.take(_questionCount - taken.length));
    return taken.take(_questionCount).toList();
  }

  List<Map<String, dynamic>> _bucketForDifficulty(
    List<Map<String, dynamic>> easy,
    List<Map<String, dynamic>> med,
    List<Map<String, dynamic>> hard,
    String d,
  ) {
    switch (d) {
      case 'easy':
        return easy.isNotEmpty
            ? easy
            : med.isNotEmpty
                ? med
                : hard;
      case 'hard':
        return hard.isNotEmpty
            ? hard
            : med.isNotEmpty
                ? med
                : easy;
      default:
        return med.isNotEmpty
            ? med
            : easy.isNotEmpty
                ? easy
                : hard;
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.previewMode) return;
    if (_timedRoundSeconds <= 0) return;

    setState(() {
      _remainingSeconds = _timedRoundSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        t.cancel();
        _handleTimeout();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _handleTimeout() {
    if (showResult) return;
    // Timeout counts as incorrect with no selected answer
    final question = _activeQuestions[currentIndex];
    final correctIndex = question['answer'] as int;
    final correctText = (question['options'][correctIndex]).toString();

    userAnswers.add({
      'question': (question['question'] ?? '').toString(),
      'selected': '⏱️ (No answer)',
      'correct': correctText,
    });

    setState(() {
      wasCorrect = false;
      showResult = true;
      streak = 0;
      _consecutiveWrong += 1;
      _consecutiveCorrect = 0;
    });

    _maybeAdjustDifficulty();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _nextQuestion();
    });
  }

  int _difficultyMultiplier() {
    switch (_currentDifficulty) {
      case 'easy':
        return 1;
      case 'hard':
        return 3;
      default:
        return 2;
    }
  }

  void _maybeAdjustDifficulty() {
    if (!_adaptiveDifficulty) return;
    // Simple classroom-style adjustment:
    // - 2 correct in a row => harder
    // - 2 wrong in a row   => easier
    if (_consecutiveCorrect >= 2) {
      _consecutiveCorrect = 0;
      _consecutiveWrong = 0;
      setState(() {
        if (_currentDifficulty == 'easy') {
          _currentDifficulty = 'medium';
        } else if (_currentDifficulty == 'medium') _currentDifficulty = 'hard';
      });
    } else if (_consecutiveWrong >= 2) {
      _consecutiveCorrect = 0;
      _consecutiveWrong = 0;
      setState(() {
        if (_currentDifficulty == 'hard') {
          _currentDifficulty = 'medium';
        } else if (_currentDifficulty == 'medium') _currentDifficulty = 'easy';
      });
    }
  }

  void _checkAnswer(String selected) {
    if (showResult) return;

    final question = _activeQuestions[currentIndex];
    final correctAnswerIndex = question['answer'] as int;
    final correctAnswerText =
        question['options'][correctAnswerIndex].toString();
    final correct = correctAnswerText == selected;

    userAnswers.add({
      'question': (question['question'] ?? '').toString(),
      'selected': selected,
      'correct': correctAnswerText,
    });

    if (widget.previewMode) {
      setState(() {
        previewSelected = selected;
        showResult = true;
      });
    } else {
      // stop timer while showing feedback
      _timer?.cancel();

      setState(() {
        wasCorrect = correct;
        showResult = true;

        if (correct) {
          correctCount++;
          streak++;
          _consecutiveCorrect += 1;
          _consecutiveWrong = 0;

          // points: base + time bonus + streak bonus
          final base = 100 * _difficultyMultiplier();
          final timeBonus =
              _timedRoundSeconds > 0 ? (_remainingSeconds * 2) : 0;
          final streakBonus = (base * (streak - 1) * 0.1).round();
          points += base + timeBonus + streakBonus;
        } else {
          streak = 0;
          _consecutiveWrong += 1;
          _consecutiveCorrect = 0;
        }
      });

      _maybeAdjustDifficulty();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (currentIndex < _activeQuestions.length - 1) {
      setState(() {
        currentIndex++;
        showResult = false;
        wasCorrect = null;
        previewSelected = null;
      });
      _startTimerIfNeeded();
    } else {
      setState(() {
        currentIndex++;
        showResult = true;
      });
      _reportCompletion(_activeQuestions.length);
    }
  }

  void _reportCompletion(int totalQuestions) {
    if (_completionReported || widget.previewMode) return;
    _completionReported = true;

    // pointsMax is approximate: max per question depends on time. We provide a
    // conservative bound for comparison.
    final approxPointsMax = totalQuestions *
        (100 * 3 + (_timedRoundSeconds * 2) + (100 * 0.2)).round();

    widget.onComplete(
      GamePlayResult(
        score: correctCount,
        maxScore: totalQuestions,
        pointsEarned: points,
        pointsMax: approxPointsMax,
        meta: {
          'mode': _mode,
          'difficultyEnd': _currentDifficulty,
          'timedRoundSeconds': _timedRoundSeconds,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeQuestions.isEmpty) {
      return const Text('No questions available for this game.');
    }

    if (currentIndex >= _activeQuestions.length) {
      _reportCompletion(_activeQuestions.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Completed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Correct: $correctCount / ${_activeQuestions.length}'),
          Text('Points: $points'),
          if (_mode == 'TEAM')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Mode: TEAM',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 20),
          ...userAnswers.map((answer) {
            final isCorrect = answer['selected'] == answer['correct'];
            return ListTile(
              title: Text(answer['question'] ?? 'No question'),
              subtitle: Text(
                isCorrect
                    ? '✅ Correct'
                    : '❌ Your answer: ${answer['selected']} | Correct: ${answer['correct']}',
              ),
            );
          }),
        ],
      );
    }

    final question = _activeQuestions[currentIndex];
    final options =
        (question['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [];

    final progressText = '${currentIndex + 1}/${_activeQuestions.length}';
    final diffLabel =
        (question['difficulty'] ?? _currentDifficulty).toString().toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question $progressText',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (!widget.previewMode && _timedRoundSeconds > 0)
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('$_remainingSeconds s'),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Difficulty: $diffLabel',
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const Spacer(),
            if (!widget.previewMode)
              Text('Points: $points', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          (question['question'] ?? 'No question').toString(),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          options.length,
          (index) {
            final option = options[index];
            return ListTile(
              title: Text(option),
              leading: Radio<String>(
                value: option,
                groupValue: widget.previewMode
                    ? previewSelected
                    : (showResult
                        ? options[(question['answer'] as int)]
                        : null),
                onChanged: showResult ? null : (_) => _checkAnswer(option),
              ),
            );
          },
        ),
        if (showResult && !widget.previewMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              wasCorrect == true ? '✅ Correct!' : '❌ Incorrect',
              style: TextStyle(
                fontSize: 18,
                color: wasCorrect == true ? Colors.green : Colors.red,
              ),
            ),
          ),
        if (widget.previewMode)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Preview Mode',
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
