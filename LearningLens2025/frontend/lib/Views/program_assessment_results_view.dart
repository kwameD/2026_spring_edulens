import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';
import 'package:learninglens_app/beans/assignment.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/beans/participant.dart';
import 'package:learninglens_app/services/program_assessment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProgramAsessmentResultsView extends StatefulWidget {
  final ProrgramAssessmentJob evaluation;
  final Course course;
  final Assignment assignment;
  final List<Participant> participants;

  const ProgramAsessmentResultsView({
    super.key,
    required this.evaluation,
    required this.course,
    required this.assignment,
    required this.participants,
  });

  @override
  _ProgramAsessmentResultsViewState createState() =>
      _ProgramAsessmentResultsViewState(
        evaluation: evaluation,
        course: course,
        assignment: assignment,
        participants: participants,
      );
}

class _ProgramAsessmentResultsViewState
    extends State<ProgramAsessmentResultsView> {
  final ProrgramAssessmentJob evaluation;
  final Course course;
  final Assignment assignment;
  final List<Participant> participants;

  final lmsService = LmsFactory.getLmsService();

  _ProgramAsessmentResultsViewState({
    required this.evaluation,
    required this.course,
    required this.assignment,
    required this.participants,
  });

  Future<void> _publishGrade(
    Participant student,
    String grade,
    String feedback,
  ) async {
    final moodleLms = LmsFactory.getLmsServiceMoodle();
    final publishedSuccessfully = await moodleLms.publishGrade(
      assignment.id.toString(),
      student.id.toString(),
      feedback,
      grade,
    );

    SnackBar snackbar;
    if (publishedSuccessfully) {
      snackbar = SnackBar(
        backgroundColor: Colors.green,
        content: Text('Grade for ${student.fullname} published successfully.'),
        duration: const Duration(seconds: 8),
      );
    } else {
      snackbar = SnackBar(
        backgroundColor: Colors.red[700],
        content: Text('Unable to publish grade for ${student.fullname}'),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackbar);
    }
  }

  // Added: fetch assignment attachments safely so the results page still renders when none exist.
  Future<List<Map<String, dynamic>>> _getAssignmentAttachments() async {
    try {
      return await lmsService.getSubmissionAttachments(assignId: assignment.id);
    } catch (_) {
      return [];
    }
  }

  // Added: handle missing result lists without crashing the page.
  List<dynamic> get _safeResultsJson {
    final rawResults = evaluation.resultsJson;
    if (rawResults is List<dynamic>) {
      return rawResults;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(
        title: 'Evaluation for ${assignment.name}',
        userprofileurl: lmsService.profileImage ?? '',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAssignmentAttachments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading submissions: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildMainLayout(snapshot.data ?? []),
          );
        },
      ),
    );
  }

  Widget _buildMainLayout(List<Map<String, dynamic>> submissionAttachments) {
    final resultsJson = _safeResultsJson;

    if (resultsJson.isEmpty) {
      return const Center(
        child: Text('No assessment results are available for this job yet.'),
      );
    }

    final children = resultsJson
        .mapIndexed((index, result) => _buildPanel(index, result, submissionAttachments))
        .toList();

    return Column(
      children: children,
    );
  }

  bool _isOutputCorrect(dynamic entry) {
    final error = entry['error'] == true;
    final expectedOutput = entry['expectedOutput'].toString().trimRight();
    final actualOutput = entry['output'].toString().trimRight();

    return !error && expectedOutput == actualOutput;
  }

  Icon _getIcon(bool isOutputCorrect) {
    if (!isOutputCorrect) {
      return const Icon(Icons.error, color: Colors.red);
    }

    return const Icon(Icons.check_circle, color: Colors.green);
  }

  Widget _codeOutput(String header, String output) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: SelectableText(output),
        ),
      ],
    );
  }

  Widget _buildViewSubmissionLink(String submissionUrl) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(submissionUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch $submissionUrl');
        }
      },
      child: const Text(
        'View Submission',
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Added: create a small label when no LMS attachment or submission link is available.
  Widget _buildMissingSubmissionLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text('Submission link unavailable'),
    );
  }

  Widget _buildPanel(
    int idx,
    dynamic result,
    List<Map<String, dynamic>> submissionAttachments,
  ) {
    final outputs = (result['outputs'] as List<dynamic>? ?? []);

    // Added: resolve the participant safely for local fallback results and incomplete data.
    final student = participants.firstWhereOrNull(
      (participant) => participant.id.toString() == result['studentId'].toString(),
    );

    final studentSubmission = submissionAttachments.firstWhereOrNull(
      (entry) => entry['userid'].toString() == result['studentId'].toString(),
    );

    final allOutputCorrectness = outputs.map(_isOutputCorrect).toList();
    final correctCount = allOutputCorrectness.where((entry) => entry).length;
    final suggestedGrade = outputs.isEmpty ? 0.0 : correctCount / outputs.length;

    final gradeController = TextEditingController();
    gradeController.text = (suggestedGrade * 100).toInt().toString();
    final feedbackController = TextEditingController();

    final children = <Widget>[];

    // Added: show the submission link only when one exists.
    if (studentSubmission != null && studentSubmission['submissionUrl'] != null) {
      children.add(_buildViewSubmissionLink(studentSubmission['submissionUrl']));
    } else {
      children.add(_buildMissingSubmissionLabel());
    }
    children.add(const SizedBox(height: 8));

    // Added: show grading controls only when a real participant is known.
    if (student != null) {
      children.add(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            children: [
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  FilteringTextInputFormatter.allow(RegExp(r'^[1-9][0-9]*$|^0$')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Suggested Grade',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                controller: feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Feedback',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  if (int.tryParse(gradeController.text) != null &&
                      int.parse(gradeController.text) > 100 &&
                      mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red[700],
                        content: const Text('Grade cannot be more than 100%'),
                      ),
                    );
                    return;
                  }

                  await _publishGrade(
                    student,
                    gradeController.text,
                    feedbackController.text,
                  );
                },
                child: const Text('Publish'),
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    // Added: show a helpful fallback message when no outputs exist.
    if (outputs.isEmpty) {
      children.add(
        const Text('No execution output was returned for this student.'),
      );
    }

    for (final entry in outputs) {
      final actualOutput = entry['output'].toString();
      final expectedOutput = entry['expectedOutput'].toString();
      final isCorrect = _isOutputCorrect(entry);

      children.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _getIcon(isCorrect),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCorrect ? 'Output matched expected result' : 'Output mismatch or error',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _codeOutput('Expected Output', expectedOutput),
                  const SizedBox(height: 12),
                  _codeOutput('Actual Output', actualOutput),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student?.fullname ?? 'Student ${idx + 1}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
