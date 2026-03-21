import 'dart:async';

import 'package:flutter/material.dart';

import 'game_result.dart';

class QuizGame extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final void Function(GamePlayResult result) onComplete;
  final bool previewMode;
  final GameSettings settings;

  const QuizGame({
    super.key,
    required this.questions,
    required this.onComplete,
    this.previewMode = false,
    this.settings = const GameSettings(),
  });

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  int currentIndex = 0;
  int score = 0;
  bool showResult = false;
  bool? wasCorrect;
  int _streak = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  List<Map<String, String>> userAnswers = [];
  String? previewSelected;
  bool _completionReported = false;
  late List<Map<String, dynamic>> _preparedQuestions;

  bool get _timedMode => widget.settings.roundTimeSeconds > 0;

  @override
  void initState() {
    super.initState();
    _preparedQuestions = _buildPlayableQuestions();
    _startTimerForCurrentQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildPlayableQuestions() {
    final normalized = widget.questions.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      map['difficulty'] = _normalizeDifficulty(map['difficulty']);
      return map;
    }).toList();

    if (normalized.isEmpty) return normalized;

    if (!widget.settings.adaptiveDifficulty) {
      normalized.sort((a, b) =>
          _difficultyRank(a['difficulty']).compareTo(_difficultyRank(b['difficulty'])));
      return normalized.take(5).toList();
    }

    final targetRank = _difficultyRank(widget.settings.difficulty);
    final exact = normalized
        .where((q) => _difficultyRank(q['difficulty']) == targetRank)
        .toList();
    final near = normalized
        .where((q) => (_difficultyRank(q['difficulty']) - targetRank).abs() == 1)
        .toList();
    final far = normalized
        .where((q) => (_difficultyRank(q['difficulty']) - targetRank).abs() > 1)
        .toList();
    return [...exact, ...near, ...far].take(5).toList();
  }

  String _normalizeDifficulty(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw == 'easy' || raw == 'medium' || raw == 'hard') return raw;
    return widget.settings.difficulty;
  }

  int _difficultyRank(dynamic value) {
    switch (_normalizeDifficulty(value)) {
      case 'easy':
        return 0;
      case 'hard':
        return 2;
      default:
        return 1;
    }
  }

  void _startTimerForCurrentQuestion() {
    _timer?.cancel();
    if (!_timedMode || currentIndex >= _preparedQuestions.length) {
      return;
    }
    _timeRemaining = widget.settings.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || showResult) return;
      if (_timeRemaining <= 1) {
        timer.cancel();
        _handleTimeout();
        return;
      }
      setState(() {
        _timeRemaining--;
      });
    });
  }

  void _handleTimeout() {
    final question = _preparedQuestions[currentIndex];
    final correctAnswerIndex = question['answer'] as int;
    final correctAnswerText = question['options'][correctAnswerIndex].toString();
    userAnswers.add({
      'question': question['question']?.toString() ?? '',
      'selected': '⏰ Time expired',
      'correct': correctAnswerText,
    });
    setState(() {
      wasCorrect = false;
      _streak = 0;
      showResult = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) nextQuestion();
    });
  }

  void checkAnswer(String selected) {
    _timer?.cancel();
    final question = _preparedQuestions[currentIndex];
    final correctAnswerIndex = question['answer'] as int;
    final correctAnswerText = question['options'][correctAnswerIndex].toString();
    final correct = correctAnswerText == selected;

    userAnswers.add({
      'question': question['question']?.toString() ?? '',
      'selected': selected,
      'correct': correctAnswerText,
    });

    setState(() {
      previewSelected = selected;
      wasCorrect = correct;

      if (correct) {
        _streak++;
        final streakBonus = _streak > 1 ? (_streak - 1) * widget.settings.streakBonus : 0;
        score += widget.settings.basePoints + streakBonus;
      } else {
        _streak = 0;
      }

      showResult = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) nextQuestion();
    });
  }

  void nextQuestion() {
    if (currentIndex < _preparedQuestions.length - 1) {
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
      _reportCompletion(_preparedQuestions.length);
    }
  }

  void _reportCompletion(int totalQuestions) {
    if (_completionReported) return;
    _completionReported = true;
    widget.onComplete(
      GamePlayResult(
        score: score,
        maxScore: totalQuestions * widget.settings.basePoints +
            (totalQuestions * widget.settings.streakBonus),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_preparedQuestions.isEmpty) {
      return const Text('No questions available.');
    }

    if (currentIndex >= _preparedQuestions.length) {
      _reportCompletion(_preparedQuestions.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Completed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Score: $score'),
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
    final question = _preparedQuestions[currentIndex];
    final questionDifficulty = _normalizeDifficulty(question['difficulty']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Question ${currentIndex + 1}/${_preparedQuestions.length}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('Mode: ${widget.settings.mode.toUpperCase()}')),
            Chip(label: Text('Difficulty: ${questionDifficulty.toUpperCase()}')),
            if (_timedMode) Chip(label: Text('Time: ${_timeRemaining}s')),
            Chip(label: Text('Streak: $_streak')),
          ],
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
                        ? question['options'][question['answer'] as int].toString()
                        : null),
                onChanged: showResult ? null : (_) => checkAnswer(option),
              ),
            );
          },
        ),
        if (showResult)
          Column(
            children: [
              Text(
                wasCorrect! ? '✅ Correct!' : '❌ Incorrect',
                style: TextStyle(
                  fontSize: 18,
                  color: wasCorrect! ? Colors.green : Colors.red,
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
                  color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
