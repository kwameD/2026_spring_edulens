import 'dart:async';

import 'package:flutter/material.dart';

import 'game_result.dart';

class MatchingGame extends StatefulWidget {
  final List<Map<String, dynamic>> pairs;
  final void Function(GamePlayResult result) onComplete;
  final bool previewMode;
  final Map<String, dynamic>? settings;

  const MatchingGame({
    super.key,
    required this.pairs,
    required this.onComplete,
    this.previewMode = false,
    this.settings,
  });

  @override
  State<MatchingGame> createState() => _MatchingGameState();
}

class _MatchingGameState extends State<MatchingGame> {
  List<String> leftItems = [];
  List<String> rightItems = [];
  Map<String, String> correctMatches = {};
  Map<String, String> userMatches = {};
  int score = 0;
  int earnedPoints = 0;
  int streak = 0;
  bool gameFinished = false;
  List<Map<String, String>> results = [];
  bool _completionReported = false;
  Timer? _timer;
  int? _timeRemaining;

  Map<String, dynamic> get _settings => widget.settings ?? const {};
  Map<String, dynamic> get _scoring =>
      Map<String, dynamic>.from(_settings['scoring'] ?? const {});
  bool get _teamMode => _settings['teamMode'] == true;
  String get _difficulty => (_settings['difficulty']?.toString() ?? 'medium');
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
    initializeGame();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _effectiveRoundTimeSeconds() {
    if (_configuredRoundTime <= 0) return 0;
    switch (_difficulty.toLowerCase()) {
      case 'easy':
        return _configuredRoundTime + 10;
      case 'hard':
        return (_configuredRoundTime - 10).clamp(10, 999);
      default:
        return _configuredRoundTime;
    }
  }

  void _startTimer() {
    if (widget.previewMode) return;
    final seconds = _effectiveRoundTimeSeconds();
    if (seconds <= 0) return;
    _timeRemaining = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || gameFinished) return;
      final nextValue = (_timeRemaining ?? 0) - 1;
      if (nextValue <= 0) {
        timer.cancel();
        _submitAnswers(timedOut: true);
      } else {
        setState(() {
          _timeRemaining = nextValue;
        });
      }
    });
  }

  void initializeGame() {
    if (widget.pairs.isEmpty) {
      debugPrint('⚠️ No pairs received.');
      return;
    }

    for (final pair in widget.pairs) {
      final term = pair['term'];
      final definition = pair['definition'] ?? pair['match'];
      if (term == null || definition == null) continue;

      final termStr = term.toString();
      final defStr = definition.toString();
      leftItems.add(termStr);
      rightItems.add(defStr);
      correctMatches[termStr] = defStr;
    }

    rightItems.shuffle();
  }

  String? _matchedTermForDefinition(String definition) {
    for (final entry in userMatches.entries) {
      if (entry.value == definition) return entry.key;
    }
    return null;
  }

  void _reportCompletion() {
    if (_completionReported || widget.previewMode) return;
    _completionReported = true;
    widget.onComplete(
      GamePlayResult(
        score: score,
        maxScore: leftItems.length,
        earnedPoints: earnedPoints,
      ),
    );
  }

  void _submitAnswers({bool timedOut = false}) {
    if (gameFinished) return;
    _timer?.cancel();

    int runningStreak = 0;
    score = 0;
    earnedPoints = 0;
    results.clear();

    for (final term in leftItems) {
      final selected =
          userMatches[term] ?? (timedOut ? 'Timed out' : 'No match');
      final correctValue = correctMatches[term] ?? '';
      final correct = selected == correctValue;
      if (!widget.previewMode && correct) {
        score++;
        runningStreak++;
        if (_scoringEnabled) {
          earnedPoints += _basePoints +
              ((runningStreak > 1 ? runningStreak - 1 : 0) * _streakBonus);
        }
      } else {
        runningStreak = 0;
      }

      results.add({
        'term': term,
        'selected': selected,
        'correct': correctValue,
        'status': correct ? '✅ Correct' : '❌ Incorrect',
      });
    }

    if (!widget.previewMode && _scoringEnabled) {
      earnedPoints += (_timeRemaining ?? 0) * _timeBonusPerSecond;
    }

    setState(() {
      streak = runningStreak;
      gameFinished = true;
    });
    _reportCompletion();
  }

  Widget _buildHeaderChips() {
    final chips = <Widget>[
      _MatchInfoChip(
        label: _teamMode ? 'Team mode' : 'Solo mode',
        icon: Icons.groups,
      ),
      _MatchInfoChip(
        label: _difficulty[0].toUpperCase() + _difficulty.substring(1),
        icon: Icons.tune,
      ),
    ];
    if (_configuredRoundTime > 0) {
      chips.add(
        _MatchInfoChip(
          label: _timeRemaining != null
              ? '$_timeRemaining s left'
              : '${_effectiveRoundTimeSeconds()} s round',
          icon: Icons.timer,
        ),
      );
    }
    if (_scoringEnabled) {
      chips.add(_MatchInfoChip(label: '$earnedPoints pts', icon: Icons.stars));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    if (gameFinished) {
      _reportCompletion();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Complete!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Correct Matches: $score / ${leftItems.length}',
              style: const TextStyle(fontSize: 16),
            ),
            if (_scoringEnabled && !widget.previewMode) ...[
              const SizedBox(height: 6),
              Text(
                'Points Earned: $earnedPoints',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 20),
            ...results.map(
              (r) => ListTile(
                title: Text(r['term'] ?? ''),
                subtitle: Text(
                  'Your Match: ${r['selected']}\nCorrect: ${r['correct']}',
                ),
                trailing: Text(r['status'] ?? ''),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderChips(),
          const SizedBox(height: 12),
          const Text(
            'Drag a term to its matching definition.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Match the terms with the correct definitions:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 400,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: leftItems.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final term = leftItems[index];
                      final isMatched = userMatches.containsKey(term);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Draggable<String>(
                          data: term,
                          feedback: Material(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.blueAccent,
                              child: Text(
                                term,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: _MatchChip(
                              label: term,
                              color: Colors.blue.shade50,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isMatched
                                  ? Colors.greenAccent.withOpacity(0.6)
                                  : Colors.blue.shade50,
                              border: Border.all(
                                color: isMatched
                                    ? Colors.green.shade700
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                term,
                                style: TextStyle(
                                  fontWeight: isMatched
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: rightItems.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final definition = rightItems[index];
                      final matchedTerm = _matchedTermForDefinition(definition);
                      return DragTarget<String>(
                        builder: (context, candidateData, rejectedData) {
                          final isDropping = candidateData.isNotEmpty;
                          final hasMatch = matchedTerm != null;
                          return GestureDetector(
                            onTap: hasMatch
                                ? () {
                                    setState(() {
                                      userMatches.remove(matchedTerm);
                                    });
                                  }
                                : null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: hasMatch
                                    ? Colors.greenAccent
                                    : isDropping
                                        ? Colors.blue.shade100
                                        : Colors.grey.shade200,
                                border: Border.all(
                                  color: hasMatch
                                      ? Colors.green.shade700
                                      : Colors.grey.shade400,
                                ),
                              ),
                              child: Text(
                                hasMatch
                                    ? '$matchedTerm → $definition'
                                    : definition,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        },
                        onAccept: (term) {
                          setState(() {
                            final existingTerm =
                                _matchedTermForDefinition(definition);
                            if (existingTerm != null) {
                              userMatches.remove(existingTerm);
                            }
                            userMatches.remove(term);
                            userMatches[term] = definition;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!gameFinished)
            ElevatedButton(
              onPressed: () => _submitAnswers(),
              child: const Text('Submit Answers'),
            ),
        ],
      ),
    );
  }
}

class _MatchChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MatchChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color,
      ),
      padding: const EdgeInsets.all(8),
      child: Text(label),
    );
  }
}

class _MatchInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MatchInfoChip({required this.label, required this.icon});

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
