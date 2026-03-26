import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learninglens_app/Api/llm/DeepSeek_api.dart';
import 'package:learninglens_app/Api/llm/grok_api.dart';
import 'package:learninglens_app/Api/llm/llm_api_modules_base.dart';
import 'package:learninglens_app/Api/llm/local_llm_service.dart';
import 'package:learninglens_app/Api/llm/openai_api.dart';
import 'package:learninglens_app/Api/llm/perplexity_api.dart';
import 'package:learninglens_app/Games/game_result.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

class AirssSimulationGame extends StatefulWidget {
  final List<Map<String, dynamic>> scenarios;
  final String title;
  final String description;
  final String llmType;
  final bool previewMode;
  final ValueChanged<GamePlayResult> onComplete;

  const AirssSimulationGame({
    super.key,
    required this.scenarios,
    required this.title,
    required this.description,
    required this.llmType,
    required this.onComplete,
    this.previewMode = false,
  });

  @override
  State<AirssSimulationGame> createState() => _AirssSimulationGameState();
}

class _AirssSimulationGameState extends State<AirssSimulationGame> {
  static const int _maxRounds = 6;
  static const List<String> _formats = [
    'Solo Sprint',
    'Team Synergy',
    'Streak Challenge',
  ];

  final TextEditingController _responseController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedScenarioIndex = 0;
  String _selectedFormat = _formats.first;
  int _currentRound = 0;
  int _empathy = 0;
  int _technicalAccuracy = 0;
  int _deEscalation = 0;
  int _optimalStreak = 0;
  bool _sessionStarted = false;
  bool _sessionFinished = false;
  bool _reflectionUnlocked = false;
  bool _submitting = false;
  bool _resultUploaded = false;
  bool _awaitingReply = false;
  String? _error;
  Map<String, dynamic>? _evidenceBundle;
  final List<_AirssTurn> _turns = [];

  @override
  void dispose() {
    _responseController.dispose();
    _reflectionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) {
      return _buildPreview();
    }

    if (!_sessionStarted) {
      return _buildSetup();
    }

    if (_sessionFinished) {
      return _buildHandover();
    }

    return _buildLiveSession();
  }

  Widget _buildPreview() {
    return SizedBox(
      width: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(widget.description),
          const SizedBox(height: 16),
          const Text(
            'AIRSS Scenarios',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...widget.scenarios.take(3).map(_scenarioCard),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    return SizedBox(
      width: 700,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(widget.description),
          const SizedBox(height: 20),
          const Text(
            'Scenario Selection',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...List.generate(widget.scenarios.length, (index) {
            final scenario = widget.scenarios[index];
            return RadioListTile<int>(
              value: index,
              groupValue: _selectedScenarioIndex,
              title: Text(
                  scenario['title']?.toString() ?? 'Scenario ${index + 1}'),
              subtitle: Text(
                '${scenario['objective'] ?? ''}\nPersona: ${scenario['persona'] ?? ''}',
              ),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedScenarioIndex = value;
                });
              },
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'Format Selection',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _formats.map((format) {
              return ChoiceChip(
                label: Text(format),
                selected: _selectedFormat == format,
                onSelected: (_) {
                  setState(() {
                    _selectedFormat = format;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: _submitting ? null : _startSession,
                child: const Text('Start Session'),
              ),
              const SizedBox(width: 12),
              const Text('6 rounds total. Crisis Event triggers at Round 4.'),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveSession() {
    final scenario = widget.scenarios[_selectedScenarioIndex];
    return SizedBox(
      width: 760,
      height: 620,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '[SESSION STATUS: Round $_currentRound/$_maxRounds | Current Score: ${_currentScore()}]',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${scenario['title']} | $_selectedFormat',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4EF),
                border: Border.all(color: const Color(0xFFD7D0C4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: _turns.length + (_awaitingReply ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (_awaitingReply && index == _turns.length) {
                    return _buildTypingIndicator();
                  }
                  final turn = _turns[index];
                  return _buildMessageBubble(turn);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD9DDE3)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message ${scenario['persona'] ?? 'stakeholder'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _responseController,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    hintText:
                        'Type your reply. Use "End Session" only if you want to stop early.',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitResponse,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_submitting ? 'Sending...' : 'Send'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The session runs for 6 of your replies unless you explicitly end it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandover() {
    final bundle = _evidenceBundle ?? _buildEvidenceBundle(reflection: '');
    final transcript = (bundle['transcript'] as List<dynamic>? ?? const []);
    final teacherSummary =
        bundle['teacher_summary'] as Map<String, dynamic>? ?? {};
    final evidenceJson =
        const JsonEncoder.withIndent('  ').convert(teacherSummary);

    return SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Transcript',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...transcript.map((entry) {
              final item = Map<String, dynamic>.from(entry as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMessageBubble(
                  _AirssTurn.fromTranscript(item),
                  compact: true,
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text(
              'Mandatory Reflection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Final score remains locked until you provide a 3-sentence reflection on: "What would you change if you had to repeat this scenario?"',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reflectionController,
              maxLines: 4,
              enabled: !_reflectionUnlocked,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Write at least 3 sentences.',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _reflectionUnlocked ? null : _submitReflection,
              child: const Text('Submit Reflection'),
            ),
            const SizedBox(height: 20),
            Text(
              _reflectionUnlocked
                  ? 'Final Competency Score: ${teacherSummary['final_competency_score'] ?? _currentScore()}'
                  : 'Final Competency Score: Locked',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            const Text(
              'Evidence Bundle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(evidenceJson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scenarioCard(Map<String, dynamic> scenario) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scenario['title']?.toString() ?? 'Scenario',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('Objective: ${scenario['objective'] ?? ''}'),
            Text('Persona: ${scenario['persona'] ?? ''}'),
            Text('Success Criteria: ${scenario['successCriteria'] ?? ''}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_AirssTurn turn, {bool compact = false}) {
    final isUser = turn.isUser;
    final bubbleColor =
        isUser ? const Color(0xFF1F4A8A) : const Color(0xFFFFFFFF);
    final textColor = isUser ? Colors.white : const Color(0xFF1F2937);
    final crossAxis =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final sender = isUser ? 'You' : 'Stakeholder';
    final timestamp = DateFormat('h:mm a').format(turn.createdAt);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 620 : 560),
        child: Column(
          crossAxisAlignment: crossAxis,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '$sender • $timestamp',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                border:
                    isUser ? null : Border.all(color: const Color(0xFFD7DEEA)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                turn.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Stakeholder',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD7DEEA)),
              ),
              child: const Text('Typing...'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    final scenario = widget.scenarios[_selectedScenarioIndex];
    final openingLine = scenario['openingLine']?.toString().trim();
    final stakeholderIntro = openingLine?.isNotEmpty == true
        ? openingLine!
        : 'We are starting now. I need answers, not generic reassurance. What is your plan?';

    setState(() {
      _turns.clear();
      _responseController.clear();
      _reflectionController.clear();
      _sessionStarted = true;
      _sessionFinished = false;
      _reflectionUnlocked = false;
      _resultUploaded = false;
      _awaitingReply = false;
      _currentRound = 1;
      _empathy = 0;
      _technicalAccuracy = 0;
      _deEscalation = 0;
      _optimalStreak = 0;
      _evidenceBundle = null;
      _turns.add(_AirssTurn(
        isUser: false,
        content: stakeholderIntro,
      ));
      _error = null;
    });
    _scrollToBottom();
  }

  Future<void> _submitResponse() async {
    final response = _responseController.text.trim();
    if (response.isEmpty) return;

    setState(() {
      _submitting = true;
      _awaitingReply = true;
      _error = null;
      _turns.add(_AirssTurn(isUser: true, content: response));
    });
    _responseController.clear();
    _scrollToBottom();

    try {
      if (_isForcedSessionEnd(response)) {
        _finishSession();
        return;
      }

      final aiReply = await _generateStakeholderReply(response);
      final deltas = _readDeltas(aiReply['scoreDeltas']);
      _empathy += deltas.$1;
      _technicalAccuracy += deltas.$2;
      _deEscalation += deltas.$3;

      final optimal = aiReply['optimal'] == true;
      if (_selectedFormat == 'Streak Challenge') {
        _optimalStreak = optimal ? _optimalStreak + 1 : 0;
      }

      setState(() {
        _awaitingReply = false;
        _turns.add(_AirssTurn(
          isUser: false,
          content: aiReply['stakeholderDialogue']?.toString() ??
              'Your answer did not resolve the concern. Try again with a tighter plan.',
        ));
        _currentRound = _nextRoundNumber();
      });
      _scrollToBottom();

      final responseCount = _responseCount();
      final reachedFinalRound = responseCount >= _maxRounds;
      final modelRequestedStop = aiReply['sessionComplete'] == true;
      if (reachedFinalRound ||
          (modelRequestedStop && (_currentRound >= _maxRounds))) {
        _finishSession();
      }
    } catch (error) {
      setState(() {
        _awaitingReply = false;
        _error = 'AIRSS simulation failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _generateStakeholderReply(
      String response) async {
    final llm = _buildLlm(widget.llmType);
    final scenario = widget.scenarios[_selectedScenarioIndex];
    final transcriptJson = jsonEncode(
      _turns
          .map((turn) => {
                'label': turn.label,
                'content': turn.content,
              })
          .toList(),
    );

    final prompt = '''
You are the AIRSS Engine running a professional roleplay.

Scenario:
${jsonEncode(scenario)}

Format: $_selectedFormat
Current round: $_currentRound of $_maxRounds
Trigger a Crisis Event at round 4 by escalating the stakeholder ask or introducing a new failure point.
Student's latest response:
$response

Transcript so far:
$transcriptJson

Respond with a JSON object only using this schema:
{
  "stakeholderDialogue": "string",
  "scoreDeltas": {
    "empathy": -2 to 5,
    "technicalAccuracy": -2 to 5,
    "deEscalation": -2 to 5
  },
  "optimal": true or false,
  "multiplierKeyword": "STAR|none|active listening|none",
  "sessionComplete": true or false
}

Rules:
- Keep stakeholder dialogue realistic, difficult, and emotionally charged.
- Use industry jargon that fits the scenario.
- The stakeholder dialogue must begin immediately with the pressure point.
- Do not reveal scoring logic.
- If the response explicitly uses STAR framing, active listening, ownership language, or a concrete recovery plan, reward it.
- Set "sessionComplete" to false unless the current round is $_maxRounds or the student clearly ends the session.
''';

    final raw = await llm.chat(prompt: prompt, temperature: 0.4);
    return _normalizeAiReply(raw);
  }

  Future<void> _submitReflection() async {
    final reflection = _reflectionController.text.trim();
    if (_sentenceCount(reflection) < 3) {
      setState(() {
        _error = 'Reflection must contain at least 3 sentences.';
      });
      return;
    }

    final bundle = _buildEvidenceBundle(reflection: reflection);
    setState(() {
      _reflectionUnlocked = true;
      _evidenceBundle = bundle;
      _error = null;
    });

    if (_resultUploaded) return;
    _resultUploaded = true;
    widget.onComplete(
      GamePlayResult(
        score: bundle['teacher_summary']['final_competency_score'] as int? ??
            _currentScore(),
        maxScore: 100,
        evidencePayload: bundle,
      ),
    );
  }

  void _finishSession() {
    if (_sessionFinished) return;
    setState(() {
      _awaitingReply = false;
      _sessionFinished = true;
      _evidenceBundle = _buildEvidenceBundle(reflection: '');
      _error = null;
    });
  }

  Map<String, dynamic> _buildEvidenceBundle({required String reflection}) {
    final strengths = _strengths();
    final weaknesses = _weaknesses();
    final reflectionQuality = _reflectionQuality(reflection);
    final now = DateTime.now();

    return {
      'transcript': _turns
          .map((turn) => {
                'label': turn.label,
                'content': turn.content,
              })
          .toList(),
      'reflection': reflection,
      'teacher_summary': {
        'final_competency_score': _currentScore(),
        'soft_skill_analysis': {
          'strengths': strengths,
          'weaknesses': weaknesses,
        },
        'completion_timestamp': DateFormat("yyyy-MM-dd HH:mm:ss").format(now),
        'reflection_quality': reflectionQuality,
      },
      'metrics': {
        'empathy': _empathy,
        'technicalAccuracy': _technicalAccuracy,
        'deEscalation': _deEscalation,
        'optimalStreak': _optimalStreak,
        'format': _selectedFormat,
        'scenario': widget.scenarios[_selectedScenarioIndex]['title'],
      },
    };
  }

  int _currentScore() {
    final basePoints =
        (_empathy + _technicalAccuracy + _deEscalation).clamp(0, 90);
    final streakMultiplier = _selectedFormat == 'Streak Challenge'
        ? (1 + (_optimalStreak * 0.15))
        : 1.0;
    final normalized = ((basePoints * streakMultiplier) / 90) * 100;
    return normalized.round().clamp(0, 100);
  }

  int _responseCount() {
    return _turns.where((turn) => turn.isUser).length;
  }

  int _nextRoundNumber() {
    final nextRound = _responseCount() + 1;
    return nextRound.clamp(1, _maxRounds);
  }

  bool _isForcedSessionEnd(String response) {
    final normalized = response.trim().toLowerCase();
    return normalized == 'end session' ||
        normalized == 'end' ||
        normalized == 'stop session';
  }

  (int, int, int) _readDeltas(dynamic raw) {
    if (raw is! Map) return (0, 0, 0);
    int read(String key) {
      final value = raw[key];
      if (value is int) return value.clamp(-2, 5);
      if (value is num) return value.round().clamp(-2, 5);
      return int.tryParse(value?.toString() ?? '')?.clamp(-2, 5) ?? 0;
    }

    return (read('empathy'), read('technicalAccuracy'), read('deEscalation'));
  }

  List<String> _strengths() {
    final metrics = _skillMetrics();
    final positiveSignals = metrics.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (positiveSignals.isEmpty) {
      return [
        'The session did not generate enough positive scoring evidence to credit a clear soft-skill strength yet.'
      ];
    }

    return positiveSignals.take(2).map((entry) {
      switch (entry.key) {
        case 'Empathy':
          return 'Empathy stayed visible under pressure.';
        case 'Technical Accuracy':
          return 'Technical explanations stayed concrete and credible.';
        case 'De-escalation':
          return 'Stakeholder pressure was contained without obvious overpromising.';
        default:
          return '${entry.key} showed measurable progress during the session.';
      }
    }).toList();
  }

  List<String> _weaknesses() {
    final ordered = _skillMetrics()..sort((a, b) => a.value.compareTo(b.value));
    final weakSignals = ordered.where((entry) => entry.value <= 0).toList();
    final summaryPool = weakSignals.isNotEmpty ? weakSignals : ordered.take(2).toList();

    return summaryPool.take(2).map((entry) {
      return '${entry.key} needs a stronger repeatable structure next attempt.';
    }).toList();
  }

  List<MapEntry<String, int>> _skillMetrics() {
    return [
      MapEntry('Empathy', _empathy),
      MapEntry('Technical Accuracy', _technicalAccuracy),
      MapEntry('De-escalation', _deEscalation),
    ];
  }

  String _reflectionQuality(String reflection) {
    final sentences = _sentenceCount(reflection);
    final wordCount = reflection
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    if (sentences >= 3 && wordCount >= 45) return 'Strong';
    if (sentences >= 3) return 'Adequate';
    return 'Insufficient';
  }

  int _sentenceCount(String reflection) {
    return reflection
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((sentence) => sentence.trim().isNotEmpty)
        .length;
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json', multiLine: true), '')
        .replaceAll(RegExp(r'```', multiLine: true), '')
        .trim();
    final start = cleaned.indexOf('{');
    if (start == -1) {
      throw const FormatException('No JSON object found in model response.');
    }
    int depth = 0;
    bool inString = false;
    bool escaping = false;
    for (int index = start; index < cleaned.length; index++) {
      final char = cleaned[index];
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          final decoded = jsonDecode(cleaned.substring(start, index + 1));
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      }
    }
    throw const FormatException('Could not isolate a complete JSON object.');
  }

  Map<String, dynamic> _normalizeAiReply(String raw) {
    try {
      final decoded = _extractJsonObject(raw);
      final dialogue = decoded['stakeholderDialogue']?.toString().trim();
      return {
        'stakeholderDialogue': dialogue?.isNotEmpty == true
            ? dialogue
            : _fallbackStakeholderReply(),
        'scoreDeltas': decoded['scoreDeltas'],
        'optimal': decoded['optimal'] == true,
        'multiplierKeyword': decoded['multiplierKeyword']?.toString() ?? 'none',
        'sessionComplete': decoded['sessionComplete'] == true,
      };
    } catch (_) {
      final fallback = _stripMarkdownFences(raw).trim();
      return {
        'stakeholderDialogue':
            fallback.isNotEmpty ? fallback : _fallbackStakeholderReply(),
        'scoreDeltas': const {
          'empathy': 0,
          'technicalAccuracy': 0,
          'deEscalation': 0,
        },
        'optimal': false,
        'multiplierKeyword': 'none',
        'sessionComplete': false,
      };
    }
  }

  String _stripMarkdownFences(String raw) {
    return raw
        .replaceAll(RegExp(r'```json', multiLine: true), '')
        .replaceAll(RegExp(r'```', multiLine: true), '');
  }

  String _fallbackStakeholderReply() {
    return 'I still need a concrete next step, timeline, and owner. What happens next?';
  }

  LLM _buildLlm(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('deep') &&
        LocalStorageService.getDeepseekKey().isNotEmpty) {
      return DeepseekLLM(LocalStorageService.getDeepseekKey());
    }
    if (normalized.contains('grok') &&
        LocalStorageService.getGrokKey().isNotEmpty) {
      return GrokLLM(LocalStorageService.getGrokKey());
    }
    if (normalized.contains('perplex') &&
        LocalStorageService.getPerplexityKey().isNotEmpty) {
      return PerplexityLLM(LocalStorageService.getPerplexityKey());
    }
    if (normalized.contains('local')) {
      return LocalLLMService();
    }
    if (LocalStorageService.getOpenAIKey().isNotEmpty) {
      return OpenAiLLM(LocalStorageService.getOpenAIKey());
    }
    if (LocalStorageService.getPerplexityKey().isNotEmpty) {
      return PerplexityLLM(LocalStorageService.getPerplexityKey());
    }
    if (LocalStorageService.getGrokKey().isNotEmpty) {
      return GrokLLM(LocalStorageService.getGrokKey());
    }
    if (LocalStorageService.getDeepseekKey().isNotEmpty) {
      return DeepseekLLM(LocalStorageService.getDeepseekKey());
    }
    throw Exception(
      'No configured LLM API key found for AIRSS. Add an OpenAI, Perplexity, Grok, or DeepSeek key in settings.',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

class _AirssTurn {
  final bool isUser;
  final String content;
  final DateTime createdAt;

  _AirssTurn({
    required this.isUser,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get label => isUser ? '[YOUR RESPONSE]' : '[STAKEHOLDER DIALOGUE]';

  factory _AirssTurn.fromTranscript(Map<String, dynamic> item) {
    final label = item['label']?.toString() ?? '';
    return _AirssTurn(
      isUser: label == '[YOUR RESPONSE]',
      content: item['content']?.toString() ?? '',
    );
  }
}
