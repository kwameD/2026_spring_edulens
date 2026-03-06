import 'dart:async';

import 'package:flutter/material.dart';

import 'game_result.dart';

class QuizGame extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final void Function(GamePlayResult result) onComplete;
  final bool previewMode;
  final Map<String, dynamic>? settings;

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
  int score = 0;
  int earnedPoints = 0;
  int streak = 0;
  bool showResult = false;
  bool? wasCorrect;
  List<Map<String, String>> userAnswers = [];
  String? previewSelected;
  bool _completionReported = false;
  Timer? _timer;
  int? _timeRemaining;

  List<Map<String, dynamic>> get _questions =>
      widget.questions.take(5).toList();
  Map<String, dynamic> get _settings => widget.settings ?? const {};
  Map<String, dynamic> get _scoring =>
      Map<String, dynamic>.from(_settings['scoring'] ?? const {});

  bool get _teamMode => _settings['teamMode'] == true;
  String get _difficulty => (_settings['difficulty']?.toString() ?? 'medium');
  bool get _adaptiveDifficulty => _settings['adaptiveDifficulty'] == true;
  bool get _scoringEnabled => _scoring['enabled'] != false;
  int get _basePoints => (_scoring['basePoints'] as num?)?.round() ?? 100;
  int get _streakBonus => (_scoring['streakBonus'] as num?)?.round() ?? 10;
  int get _timeBonusPerSecond =>
      (_scoring['timeBonusPerSecond'] as num?)?.round() ?? 5;
  int get _configuredRoundTime =>
      (_settings['roundTimeSeconds'] as num?)?.round() ?? 0;

  @override
  void initState() {
    super.initState();
    _startTimerForCurrentQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _effectiveRoundTimeSeconds() {
    if (_configuredRoundTime <= 0) return 0;

    int seconds = _configuredRoundTime;
    switch (_difficulty.toLowerCase()) {
      case 'easy':
        seconds += 5;
      case 'hard':
        seconds = (seconds - 5).clamp(5, 999);
      default:
        break;
    }

    if (_adaptiveDifficulty) {
      if (streak >= 2) {
        seconds = (seconds - 3).clamp(5, 999);
      } else if (streak == 0 && currentIndex > 0) {
        seconds += 2;
      }
    }

    return seconds;
  }

  void _startTimerForCurrentQuestion() {
    _timer?.cancel();
    if (widget.previewMode) return;

    final seconds = _effectiveRoundTimeSeconds();
    if (seconds <= 0 || currentIndex >= _questions.length) {
      setState(() {
        _timeRemaining = null;
      });
      return;
    }

    setState(() {
      _timeRemaining = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || showResult) return;
      final nextValue = (_timeRemaining ?? 0) - 1;
      if (nextValue <= 0) {
        timer.cancel();
        _handleTimeout();
      } else {
        setState(() {
          _timeRemaining = nextValue;
        });
      }
    });
  }

  void _handleTimeout() {
    if (showResult || currentIndex >= _questions.length) return;
    final question = _questions[currentIndex];
    final correctAnswerIndex = question['answer'] as int;
    final correctAnswerText =
        question['options'][correctAnswerIndex].toString();

    userAnswers.add({
      'question': question['question']?.toString() ?? 'No question',
      'selected': 'Timed out',
      'correct': correctAnswerText,
    });

    setState(() {
      wasCorrect = false;
      streak = 0;
      showResult = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) nextQuestion();
    });
  }

  void checkAnswer(String selected) {
    if (showResult) return;
    _timer?.cancel();

    final question = _questions[currentIndex];
    final correctAnswerIndex = question['answer'] as int;
    final correctAnswerText =
        question['options'][correctAnswerIndex].toString();
    final correct = correctAnswerText == selected;

    userAnswers.add({
      'question': question['question']?.toString() ?? 'No question',
      'selected': selected,
      'correct': correctAnswerText,
    });

    if (widget.previewMode) {
      setState(() {
        previewSelected = selected;
        showResult = true;
      });
    } else {
      final nextStreak = correct ? streak + 1 : 0;
      final awardedPoints = !_scoringEnabled || !correct
          ? 0
          : _basePoints +
              ((nextStreak > 1 ? nextStreak - 1 : 0) * _streakBonus) +
              ((_timeRemaining ?? 0) * _timeBonusPerSecond);

      setState(() {
        wasCorrect = correct;
        if (correct) score++;
        streak = nextStreak;
        earnedPoints += awardedPoints;
        showResult = true;
      });
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) nextQuestion();
    });
  }

  void nextQuestion() {
    if (currentIndex < _questions.length - 1) {
      setState(() {
        currentIndex++;
        showResult = false;
        wasCorrect = null;
        previewSelected = null;
      });
      _startTimerForCurrentQuestion();
    } else {
      setState(() {
        currentIndex++;
        showResult = true;
      });
      _reportCompletion(_questions.length);
    }
  }

  void _reportCompletion(int totalQuestions) {
    if (_completionReported || widget.previewMode) return;
    _completionReported = true;
    widget.onComplete(
      GamePlayResult(
        score: score,
        maxScore: totalQuestions,
        earnedPoints: earnedPoints,
      ),
    );
  }

  Widget _buildConfigRow() {
    final chips = <Widget>[
      _InfoChip(
          label: _teamMode ? 'Team mode' : 'Solo mode', icon: Icons.groups),
      _InfoChip(
          label: _difficulty[0].toUpperCase() + _difficulty.substring(1),
          icon: Icons.tune),
    ];
    if (_configuredRoundTime > 0) {
      chips.add(_InfoChip(
        label: _timeRemaining != null
            ? '$_timeRemaining s left'
            : '${_effectiveRoundTimeSeconds()} s round',
        icon: Icons.timer,
      ));
    }
    if (_scoringEnabled) {
      chips.add(_InfoChip(label: '$earnedPoints pts', icon: Icons.stars));
      chips.add(_InfoChip(
          label: 'Streak $streak', icon: Icons.local_fire_department));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= _questions.length) {
      _reportCompletion(_questions.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Completed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Correct Answers: $score / ${_questions.length}'),
          if (_scoringEnabled && !widget.previewMode) ...[
            const SizedBox(height: 6),
            Text('Points Earned: $earnedPoints'),
          ],
          const SizedBox(height: 20),
          ...userAnswers.map((answer) {
            final isCorrect = answer['selected'] == answer['correct'];
            return ListTile(
              title: Text(answer['question'] ?? 'No question'),
              subtitle: Text(
                isCorrect
                    ? '✅ You answered correctly'
                    : '❌ Your answer: ${answer['selected']} | Correct: ${answer['correct']}',
              ),
            );
          }),
        ],
      );
    }

    final question = _questions[currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigRow(),
        const SizedBox(height: 16),
        Text(
          'Question ${currentIndex + 1}/${_questions.length}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          question['question']?.toString() ?? 'No question',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          question['options']?.length ?? 0,
          (index) {
            final option = question['options'][index].toString();
            return ListTile(
              title: Text(option),
              leading: Radio<String>(
                value: option,
                groupValue: widget.previewMode
                    ? previewSelected
                    : (showResult
                        ? question['options'][question['answer'] as int]
                            .toString()
                        : null),
                onChanged: showResult ? null : (_) => checkAnswer(option),
              ),
            );
          },
        ),
        if (showResult && !widget.previewMode)
          Column(
            children: [
              Text(
                wasCorrect == true ? '✅ Correct!' : '❌ Incorrect',
                style: TextStyle(
                  fontSize: 18,
                  color: wasCorrect == true ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        if (widget.previewMode)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Preview Mode',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
