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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _turns.length,
                itemBuilder: (context, index) {
                  final turn = _turns[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turn.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(turn.content),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '[STAKEHOLDER DIALOGUE]',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _responseController,
            maxLines: 4,
            enabled: !_submitting,
            decoration: const InputDecoration(
              hintText:
                  'Enter your response. Use "End Session" to force completion.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _submitting ? null : _submitResponse,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Response'),
              ),
              if (_error != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ],
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('${item['label']}: ${item['content']}'),
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

  Future<void> _startSession() async {
    final scenario = widget.scenarios[_selectedScenarioIndex];
    final openingLine = scenario['openingLine']?.toString().trim();
    final stakeholderIntro = openingLine?.isNotEmpty == true
        ? openingLine!
        : 'We are starting now. I need answers, not generic reassurance. What is your plan?';

    setState(() {
      _sessionStarted = true;
      _currentRound = 1;
      _turns.add(_AirssTurn(
        label: '[STAKEHOLDER DIALOGUE]',
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
      _error = null;
      _turns.add(_AirssTurn(label: '[YOUR RESPONSE]', content: response));
    });
    _responseController.clear();
    _scrollToBottom();

    try {
      if (response.toLowerCase() == 'end session') {
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
        _turns.add(_AirssTurn(
          label: '[STAKEHOLDER DIALOGUE]',
          content: aiReply['stakeholderDialogue']?.toString() ??
              'Your answer did not resolve the concern. Try again with a tighter plan.',
        ));
        _currentRound = (_currentRound + 1).clamp(1, _maxRounds);
      });
      _scrollToBottom();

      if (aiReply['sessionComplete'] == true ||
          _turns.where((t) => t.label == '[YOUR RESPONSE]').length >=
              _maxRounds) {
        _finishSession();
      }
    } catch (error) {
      setState(() {
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
- Set "sessionComplete" to true at the final round or if the student clearly ends the session.
''';

    final raw = await llm.chat(prompt: prompt, temperature: 0.4);
    return _extractJsonObject(raw);
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
    setState(() {
      _sessionFinished = true;
      _evidenceBundle = _buildEvidenceBundle(reflection: '');
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
    final strengths = <String>[];
    if (_empathy >= _technicalAccuracy && _empathy >= _deEscalation) {
      strengths.add('Empathy stayed visible under pressure.');
    }
    if (_technicalAccuracy >= _empathy && _technicalAccuracy >= _deEscalation) {
      strengths.add('Technical explanations stayed concrete and credible.');
    }
    if (_deEscalation >= _empathy && _deEscalation >= _technicalAccuracy) {
      strengths.add(
          'Stakeholder pressure was contained without obvious overpromising.');
    }
    return strengths.isEmpty
        ? ['Session completed with balanced but limited evidence.']
        : strengths;
  }

  List<String> _weaknesses() {
    final ordered = {
      'Empathy': _empathy,
      'Technical Accuracy': _technicalAccuracy,
      'De-escalation': _deEscalation,
    }.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return ordered.take(2).map((entry) {
      return '${entry.key} needs a stronger repeatable structure next attempt.';
    }).toList();
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
  final String label;
  final String content;

  const _AirssTurn({
    required this.label,
    required this.content,
  });
}
