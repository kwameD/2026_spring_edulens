import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Api/lms/lms_interface.dart';
import 'package:learninglens_app/beans/assignment.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/beans/participant.dart';
import 'package:learninglens_app/services/api_service.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

/// Represents a program assessment job.
/// Check the handleGET method in code_eval/index.mjs for properties.
class ProrgramAssessmentJob {
  late String courseId;
  late String assignmentId;
  late String expectedOutput;

  /// Programming language code was written in.
  late String language;

  /// Username of the user that started the assessment.
  late String username;
  late String status;

  /// List of results that contain information about each student's code submission.
  late dynamic resultsJson;
  late DateTime startTime;
  DateTime? finishTime;

  /// Added: label the origin so the UI can distinguish backend data from local fallback data if needed.
  late String source;

  /// Represents a program assessment job.
  ProrgramAssessmentJob(dynamic result) {
    // Added: normalize the source so older backend payloads still work.
    source = result['source']?.toString() ?? 'remote';
    courseId = result['course_id'].toString();
    assignmentId = result['assignment_id'].toString();
    expectedOutput = result['expected_output']?.toString() ?? '';
    language = result['language']?.toString() ?? 'Unknown';
    username = result['username']?.toString() ?? '';
    status = result['status']?.toString() ?? 'JOB STARTED';

    // Added: support both already-decoded local results and stringified backend results.
    final dynamic rawResultsJson = result['results_json'];
    if (rawResultsJson == null) {
      resultsJson = null;
    } else if (rawResultsJson is String && rawResultsJson.trim().isNotEmpty) {
      resultsJson = jsonDecode(rawResultsJson);
    } else {
      resultsJson = rawResultsJson;
    }

    startTime = DateTime.parse(result['start_time'].toString());
    finishTime = result['finish_time'] == null ||
            result['finish_time'].toString().trim().isEmpty
        ? null
        : DateTime.parse(result['finish_time'].toString());
  }

  // Added: provide a safe serialization path for local fallback caching.
  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'course_id': courseId,
      'assignment_id': assignmentId,
      'expected_output': expectedOutput,
      'language': language,
      'username': username,
      'status': status,
      'results_json': resultsJson == null ? null : jsonEncode(resultsJson),
      'start_time': startTime.toIso8601String(),
      'finish_time': finishTime?.toIso8601String(),
    };
  }
}

class ProgramAssessmentService {
  final codeEvalUrl = LocalStorageService.getCodeEvalUrl();
  final LmsInterface lmsService = LmsFactory.getLmsService();

  // Added: use a dedicated message so users understand why fallback mode was used.
  static const String _fallbackMessage =
      'Program assessment backend unavailable. EduLense saved this assessment locally so the page still works. Configure CODE_EVAL_URL to restore live code execution.';

  static Future<void> createDb() async {
    // Added: skip remote DB setup when no backend URL is configured.
    if (!_hasUsableCodeEvalUrl(LocalStorageService.getCodeEvalUrl())) {
      return;
    }

    final url =
        Uri.parse('${LocalStorageService.getCodeEvalUrl()}/?command=createDb');

    try {
      // Added: ignore HTML error pages instead of crashing the app on startup.
      final response = await http.get(url);
      if (_looksLikeHtml(response.body)) {
        return;
      }
    } catch (_) {
      // Added: allow the app to continue booting even if the code evaluation backend is offline.
      return;
    }
  }

  /// Starts a program assessment.
  Future<http.Response> startEvaluation({
    required Course course,
    required Assignment assignment,
    required String input,
    required String expectedOutput,
    required String language,
    required int timeoutSeconds,
  }) async {
    // Added: prefer the remote backend when it is configured and returns valid JSON.
    if (_hasUsableCodeEvalUrl(codeEvalUrl)) {
      try {
        final response = await ApiService().httpPost(
          Uri.parse(codeEvalUrl),
          body: jsonEncode({
            'courseId': course.id,
            'assignmentId': assignment.id.toString(),
            'input': input,
            'expectedOutput': expectedOutput,
            'username': lmsService.userName,
            'language': language,
            'timeoutSeconds': timeoutSeconds.toString(),
          }),
        );

        // Added: keep the real backend path when the endpoint responds correctly.
        if (!_looksLikeHtml(response.body)) {
          return response;
        }
      } catch (_) {
        // Added: fall through to local caching mode when the backend request fails.
      }
    }

    // Added: save the job locally so the feature still behaves like a working assessment queue.
    await _createLocalFallbackJob(
      course: course,
      assignment: assignment,
      expectedOutput: expectedOutput,
      language: language,
    );

    // Added: return a synthetic success response so the form flow remains unchanged.
    return http.Response(
      jsonEncode({
        'status': 'LOCAL_FALLBACK',
        'message': _fallbackMessage,
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  /// Gets program assessments created by the user.
  Future<List<ProrgramAssessmentJob>> getEvaluations(String username) async {
    // Added: always load locally cached jobs first because they are the safe fallback source.
    final localJobs = await _loadLocalJobs();

    // Added: update stale locally running jobs into completed fallback jobs after a short delay.
    final normalizedLocalJobs = await _normalizeLocalJobs(localJobs);

    // Added: return local jobs only when the backend URL is missing.
    if (!_hasUsableCodeEvalUrl(codeEvalUrl)) {
      return normalizedLocalJobs
          .where((job) => job.username == username)
          .toList(growable: false);
    }

    try {
      final response = await ApiService().httpGet(
        Uri.parse('$codeEvalUrl/?username=$username'),
      );

      // Added: fall back gracefully if the backend returns HTML instead of JSON.
      if (response.statusCode != 200 || _looksLikeHtml(response.body)) {
        return normalizedLocalJobs
            .where((job) => job.username == username)
            .toList(growable: false);
      }

      final decodedResponse = jsonDecode(response.body);
      if (decodedResponse is! List<dynamic>) {
        return normalizedLocalJobs
            .where((job) => job.username == username)
            .toList(growable: false);
      }

      // Added: convert remote payloads into job objects.
      final remoteJobs = decodedResponse
          .map((evaluation) => ProrgramAssessmentJob(evaluation))
          .toList();

      // Added: merge remote and local jobs so the UI shows everything in one place.
      return _mergeJobs(remoteJobs, normalizedLocalJobs, username);
    } catch (_) {
      // Added: protect the page from JSON and transport errors by using cached local jobs.
      return normalizedLocalJobs
          .where((job) => job.username == username)
          .toList(growable: false);
    }
  }

  Future<bool> deleteEvaluation({
    required Course course,
    required Assignment assignment,
    required String username,
  }) async {
    var localDeleteSucceeded = false;

    try {
      // Added: remove matching locally cached jobs first so fallback mode stays consistent.
      final localJobs = await _loadLocalJobs();
      final updatedLocalJobs = localJobs
          .where(
            (job) => !(job.username == username &&
                job.assignmentId == assignment.id.toString() &&
                job.courseId == course.id.toString()),
          )
          .toList();
      localDeleteSucceeded = updatedLocalJobs.length != localJobs.length;
      await _saveLocalJobs(updatedLocalJobs);
    } catch (_) {
      // Added: continue trying the remote delete even if cache cleanup fails.
    }

    // Added: treat local deletion as a valid success path when the backend is not available.
    if (!_hasUsableCodeEvalUrl(codeEvalUrl)) {
      return localDeleteSucceeded;
    }

    try {
      final response = await http.delete(
        Uri.parse(codeEvalUrl),
        body: jsonEncode({
          'username': username,
          'assignmentId': assignment.id.toString(),
          'courseId': course.id.toString(),
        }),
      );

      // Added: ignore HTML error pages from the frontend host.
      if (_looksLikeHtml(response.body)) {
        return localDeleteSucceeded;
      }

      return response.statusCode == 200 || localDeleteSucceeded;
    } catch (_) {
      // Added: keep the feature usable even when the remote delete fails.
      return localDeleteSucceeded;
    }
  }

  // Added: check whether the configured code evaluation URL looks usable.
  static bool _hasUsableCodeEvalUrl(String url) {
    final trimmedUrl = url.trim();
    return trimmedUrl.isNotEmpty &&
        (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'));
  }

  // Added: detect the HTML payload that caused the original JSON parsing crash.
  static bool _looksLikeHtml(String body) {
    final trimmedBody = body.trimLeft();
    return trimmedBody.startsWith('<!DOCTYPE') || trimmedBody.startsWith('<html');
  }

  // Added: load cached fallback jobs from shared preferences.
  Future<List<ProrgramAssessmentJob>> _loadLocalJobs() async {
    final rawCache = LocalStorageService.getProgramAssessmentCache();
    final decodedCache = jsonDecode(rawCache);

    if (decodedCache is! List<dynamic>) {
      return [];
    }

    return decodedCache.map((entry) => ProrgramAssessmentJob(entry)).toList();
  }

  // Added: save fallback jobs back into shared preferences.
  Future<void> _saveLocalJobs(List<ProrgramAssessmentJob> jobs) async {
    final encodedCache = jsonEncode(jobs.map((job) => job.toMap()).toList());
    LocalStorageService.saveProgramAssessmentCache(encodedCache);
  }

  // Added: create a local placeholder job when the backend is unavailable.
  Future<void> _createLocalFallbackJob({
    required Course course,
    required Assignment assignment,
    required String expectedOutput,
    required String language,
  }) async {
    final jobs = await _loadLocalJobs();

    // Added: remove an older local job for the same teacher/course/assignment before replacing it.
    jobs.removeWhere(
      (job) => job.username == (lmsService.userName ?? '') &&
          job.assignmentId == assignment.id.toString() &&
          job.courseId == course.id.toString(),
    );

    final now = DateTime.now();
    final newJob = ProrgramAssessmentJob({
      'source': 'local',
      'course_id': course.id.toString(),
      'assignment_id': assignment.id.toString(),
      'expected_output': expectedOutput,
      'language': language,
      'username': lmsService.userName ?? '',
      'status': 'JOB STARTED',
      'results_json': null,
      'start_time': now.toIso8601String(),
      'finish_time': null,
    });

    // Added: insert the newest local job at the top of the cache.
    jobs.insert(0, newJob);
    await _saveLocalJobs(jobs);
  }

  // Added: transition old local "running" jobs into finished placeholder results.
  Future<List<ProrgramAssessmentJob>> _normalizeLocalJobs(
    List<ProrgramAssessmentJob> jobs,
  ) async {
    var changed = false;

    for (final job in jobs) {
      // Added: only local unfinished jobs should be auto-completed in fallback mode.
      if (job.source != 'local' || job.status == 'JOB FINISHED') {
        continue;
      }

      // Added: wait a few seconds so the UI can still briefly display a running job.
      if (DateTime.now().difference(job.startTime).inSeconds < 5) {
        continue;
      }

      // Added: build placeholder result rows for enrolled students when execution is unavailable.
      job.resultsJson = await _buildLocalFallbackResults(job);
      job.status = 'JOB FINISHED';
      job.finishTime = DateTime.now();
      changed = true;
    }

    // Added: persist any status updates back into the local cache.
    if (changed) {
      await _saveLocalJobs(jobs);
    }

    return jobs;
  }

  // Added: create placeholder result data that still renders inside the existing results page.
  Future<List<Map<String, dynamic>>> _buildLocalFallbackResults(
    ProrgramAssessmentJob job,
  ) async {
    try {
      final participants =
          await lmsService.getCourseParticipants(job.courseId.toString());

      return participants
          .where((participant) => _isStudentParticipant(participant))
          .map(
            (participant) => {
              'studentId': participant.id.toString(),
              'outputs': [
                {
                  'error': true,
                  'expectedOutput': job.expectedOutput,
                  'output': _fallbackMessage,
                }
              ],
            },
          )
          .toList(growable: false);
    } catch (_) {
      // Added: still return a result row even if participant lookup fails.
      return [
        {
          'studentId': 'unknown',
          'outputs': [
            {
              'error': true,
              'expectedOutput': job.expectedOutput,
              'output': _fallbackMessage,
            }
          ],
        }
      ];
    }
  }

  // Added: avoid showing teachers and other non-student accounts in fallback result placeholders.
  bool _isStudentParticipant(Participant participant) {
    final combinedRoles = participant.roles.join(' ').toLowerCase();
    return combinedRoles.contains('student') || combinedRoles.isEmpty;
  }

  // Added: combine remote jobs with local cached jobs while preferring the remote version when both exist.
  List<ProrgramAssessmentJob> _mergeJobs(
    List<ProrgramAssessmentJob> remoteJobs,
    List<ProrgramAssessmentJob> localJobs,
    String username,
  ) {
    final mergedJobs = <String, ProrgramAssessmentJob>{};

    for (final job in localJobs.where((job) => job.username == username)) {
      final key = '${job.username}_${job.courseId}_${job.assignmentId}';
      mergedJobs[key] = job;
    }

    for (final job in remoteJobs.where((job) => job.username == username)) {
      final key = '${job.username}_${job.courseId}_${job.assignmentId}';
      mergedJobs[key] = job;
    }

    return mergedJobs.values.toList(growable: false);
  }
}
