import 'package:flutter/material.dart';
import 'package:learninglens_app/theme/app_theme_helper.dart';

/// Added: data model for the polished task-based workflow configuration.
class WorkflowSupportState {
  /// Added: selected workflow stage currently highlighted by the educator or student.
  final String currentStage;

  /// Added: selected AI assistance level used for integrity nudges and scaffolding.
  final String aiUseLevel;

  /// Added: micro-reflection prompt entered inside the task flow.
  final String reflectionPrompt;

  /// Added: justification prompt reminding the learner to explain AI accept/reject decisions.
  final String integrityPrompt;

  const WorkflowSupportState({
    required this.currentStage,
    required this.aiUseLevel,
    required this.reflectionPrompt,
    required this.integrityPrompt,
  });

  /// Added: convenience method for updating only specific workflow fields.
  WorkflowSupportState copyWith({
    String? currentStage,
    String? aiUseLevel,
    String? reflectionPrompt,
    String? integrityPrompt,
  }) {
    return WorkflowSupportState(
      currentStage: currentStage ?? this.currentStage,
      aiUseLevel: aiUseLevel ?? this.aiUseLevel,
      reflectionPrompt: reflectionPrompt ?? this.reflectionPrompt,
      integrityPrompt: integrityPrompt ?? this.integrityPrompt,
    );
  }
}

/// Added: reusable workflow and AI-literacy panel for end-to-end task support.
class WorkflowSupportPanel extends StatelessWidget {
  /// Added: current workflow-support configuration.
  final WorkflowSupportState state;

  /// Added: callback for updating workflow-support fields from the host page.
  final ValueChanged<WorkflowSupportState> onChanged;

  const WorkflowSupportPanel({
    super.key,
    required this.state,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Added: define the guided workflow stages requested for stronger task-based navigation.
    const stages = [
      'Understand Prompt',
      'Plan',
      'Draft',
      'Revise',
      'Reflect',
      'Submit',
    ];

    // Added: define AI-use levels for hinting vs rewriting vs co-drafting alignment.
    const aiLevels = [
      'Hinting only',
      'Guided planning',
      'Co-drafting',
      'Revision support',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppThemeHelper.panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task-Based Workflow + AI Literacy Scaffolding',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppThemeHelper.titleColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guide learners through an end-to-end workflow with clearer stage markers, embedded micro-reflections, integrity nudges, and explicit AI/student responsibility labels.',
            style: TextStyle(
              color: AppThemeHelper.bodyColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Workflow stage markers',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppThemeHelper.titleColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stages.map((stage) {
              // Added: determine whether the chip is the currently highlighted stage.
              final isSelected = stage == state.currentStage;

              return ChoiceChip(
                label: Text(stage),
                selected: isSelected,
                onSelected: (_) {
                  // Added: report the selected workflow stage back to the host page.
                  onChanged(state.copyWith(currentStage: stage));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: state.aiUseLevel,
            decoration: const InputDecoration(
              labelText: 'AI use level',
              border: OutlineInputBorder(),
            ),
            items: aiLevels
                .map(
                  (level) => DropdownMenuItem<String>(
                    value: level,
                    child: Text(level),
                  ),
                )
                .toList(),
            onChanged: (value) {
              // Added: update the AI-use level to support hinting vs co-drafting distinctions.
              onChanged(state.copyWith(aiUseLevel: value ?? state.aiUseLevel));
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: state.reflectionPrompt,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Embedded micro-reflection prompt',
              hintText:
                  'Example: What idea did you keep from the AI, and what did you change to make it your own?',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // Added: persist the in-task reflection prompt in the page state.
              onChanged(state.copyWith(reflectionPrompt: value));
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: state.integrityPrompt,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Integrity nudge / decision justification prompt',
              hintText:
                  'Example: Explain why you accepted, revised, or rejected the AI suggestion before moving to the next stage.',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // Added: persist the integrity-justification prompt in the page state.
              onChanged(state.copyWith(integrityPrompt: value));
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('AI suggestion')), 
              Chip(label: Text('Student decision')), 
              Chip(label: Text('Student-authored content')),
              Chip(label: Text('Teacher-ready export summary')),
              Chip(label: Text('Full workflow log')),
            ],
          ),
        ],
      ),
    );
  }
}
