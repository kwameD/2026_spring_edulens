import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';
import 'package:learninglens_app/Views/program_assessment_form.dart';
import 'package:learninglens_app/Views/program_assessment_results_view.dart';
import 'package:learninglens_app/beans/assignment.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/services/local_storage_service.dart';
import 'package:learninglens_app/services/program_assessment_service.dart';
import 'package:learninglens_app/theme/app_theme_helper.dart';

class ProgramAssessmentView extends StatefulWidget {
  const ProgramAssessmentView({super.key});

  @override
  ProgramAssessmentState createState() => ProgramAssessmentState();
}

class EvaluationDataSource extends DataTableSource {
  final BuildContext context;
  final List<ProrgramAssessmentJob> results;
  final List<Course> courses;
  final dynamic lmsService;
  final Future<void> Function(
    Course course,
    Assignment assignment,
    ProrgramAssessmentJob job,
  ) onDelete;

  EvaluationDataSource({
    required this.context,
    required this.results,
    required this.courses,
    required this.lmsService,
    required this.onDelete,
  });

  // Added: centralize date formatting so the table and future UI updates stay consistent.
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    // Added: present times in the educator's local timezone for web and desktop sessions.
    final localDateTime = dateTime.toLocal();
    // Added: format the date exactly like the provided design reference.
    final datePart = DateFormat('MM/dd/yyyy').format(localDateTime);
    // Added: keep a readable 12-hour timestamp.
    final timePart = DateFormat('hh:mm a').format(localDateTime);

    return '$datePart at $timePart';
  }

  // Added: safely resolve courses that may have been archived or are still loading.
  Course? _findCourse(ProrgramAssessmentJob result) {
    try {
      // Added: match the stored course id to the LMS course object.
      return courses.firstWhere(
        (course) => course.id.toString() == result.courseId,
      );
    } catch (_) {
      // Added: return null instead of crashing the entire table.
      return null;
    }
  }

  // Added: safely resolve assignments that may no longer exist in the course.
  Assignment? _findAssignment(Course? course, ProrgramAssessmentJob result) {
    if (course == null || course.essays == null) {
      // Added: avoid null errors when course essays have not loaded yet.
      return null;
    }

    try {
      // Added: match the stored assignment id to the current assignment list.
      return course.essays!.firstWhere(
        (assignment) => assignment.id.toString() == result.assignmentId,
      );
    } catch (_) {
      // Added: return null so the row can still render a fallback label.
      return null;
    }
  }

  // Added: compute a human-readable runtime so the table is more informative than raw timestamps alone.
  String _formatDuration(ProrgramAssessmentJob result) {
    final finishTime = result.finishTime;

    if (finishTime == null) {
      // Added: show that unfinished jobs are still active.
      return 'In progress';
    }

    // Added: calculate how long the assessment took from start to finish.
    final duration = finishTime.difference(result.startTime);

    if (duration.inSeconds < 60) {
      // Added: display short jobs in seconds for precision.
      return '${duration.inSeconds}s';
    }

    // Added: display longer jobs in minutes and seconds for readability.
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  // Added: render status as a colored chip to better match the polished desktop mockup.
  Widget _statusChip(String status) {
    // Added: normalize status checks because the backend uses uppercase strings.
    final normalizedStatus = status.toUpperCase();
    // Added: pick a green chip for finished jobs.
    final isFinished = normalizedStatus == 'JOB FINISHED';
    // Added: use theme-friendly colors that still communicate job state clearly.
    final backgroundColor = isFinished
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    // Added: keep text contrast strong enough for accessibility.
    final foregroundColor = isFinished
        ? const Color(0xFF2E7D32)
        : const Color(0xFFEF6C00);

    return Container(
      // Added: mimic a pill-style status badge.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // Added: round the badge to soften the desktop UI.
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        // Added: emphasize status without overwhelming the row.
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // Added: build a compact secondary action button similar to the reference image.
  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return ElevatedButton(
      // Added: pass through enabled and disabled states from the table row.
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Added: use a very light surface tint for the view button.
        backgroundColor: AppThemeHelper.tint(context),
        // Added: keep the purple text aligned with the app theme.
        foregroundColor: const Color(0xFF7C4DFF),
        // Added: create the soft rounded desktop pill seen in the screenshot.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        // Added: size the button closer to the design reference.
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        elevation: 0,
      ),
      child: Text(label),
    );
  }

  // Added: build a stronger destructive action button that still fits the polished UI.
  Widget _buildDeleteButton({
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      // Added: enable deletion only when the caller allows it.
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Added: use a vibrant red similar to the provided screenshot.
        backgroundColor: const Color(0xFFFF5A52),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
      icon: const Icon(Icons.delete, size: 16),
      label: const Text('Delete'),
    );
  }

  @override
  DataRow? getRow(int index) {
    if (index >= results.length) return null;
    final result = results[index];

    // Added: resolve the matching course safely so missing LMS data does not crash the UI.
    final course = _findCourse(result);
    // Added: resolve the matching assignment safely for the same reason.
    final assignment = _findAssignment(course, result);

    // Added: fall back to readable placeholders when data cannot be resolved.
    final courseName = course?.fullName ?? 'Unknown Course';
    // Added: show a fallback assignment label if the assignment was removed or not found.
    final assignmentName = assignment?.name ?? 'Unknown Assignment';

    final startTime = _formatDateTime(result.startTime);
    final finishTime = _formatDateTime(result.finishTime);

    // Added: preserve the existing safety rule for deleting stuck jobs after 30 seconds.
    final thirtySecondsPassed =
        DateTime.now().difference(result.startTime).inSeconds >= 30;

    return DataRow(
      // Added: use theme-aware row colors so dark mode stays readable.
      color: MaterialStatePropertyAll(AppThemeHelper.cardColor(context)),
      cells: [
        DataCell(Text(courseName)),
        DataCell(Text(assignmentName)),
        DataCell(Text(result.language)),
        DataCell(_statusChip(result.status)),
        DataCell(Text(startTime)),
        DataCell(Text(finishTime.isEmpty ? _formatDuration(result) : finishTime)),
        DataCell(
          Wrap(
            // Added: allow the action buttons to wrap gracefully on narrower desktop windows.
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSecondaryButton(
                onPressed: result.status == 'JOB FINISHED' &&
                        course != null &&
                        assignment != null
                    ? () async {
                        // Added: load course participants only when the educator opens results.
                        final participants = await lmsService
                            .getCourseParticipants(course.id.toString());
                        // Added: navigate to the detailed results screen for finished jobs.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProgramAsessmentResultsView(
                              evaluation: result,
                              assignment: assignment,
                              course: course,
                              participants: participants,
                            ),
                          ),
                        );
                      }
                    : null,
                label: 'View',
              ),
              _buildDeleteButton(
                onPressed: (result.status == 'JOB FINISHED' ||
                            thirtySecondsPassed) &&
                        course != null &&
                        assignment != null
                    ? () async {
                        // Added: ask for confirmation before removing a completed or stale job.
                        final confirmDelete = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: Text(
                                'Are you sure you want to delete the evaluation for assignment "$assignmentName"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmDelete == true) {
                          // Added: forward the delete request to the parent state only after confirmation.
                          await onDelete(course, assignment, result);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => results.length;

  @override
  int get selectedRowCount => 0;
}

class EvaluationTable extends StatelessWidget {
  final List<ProrgramAssessmentJob> evaluationResults;
  final List<Course> courses;
  final dynamic lmsService;
  final Future<void> Function(
    Course course,
    Assignment assignment,
    ProrgramAssessmentJob job,
  ) onDelete;

  const EvaluationTable({
    super.key,
    required this.evaluationResults,
    required this.courses,
    required this.lmsService,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dataSource = EvaluationDataSource(
      context: context,
      results: evaluationResults,
      courses: courses,
      lmsService: lmsService,
      onDelete: onDelete,
    );

    final headingStyle = TextStyle(
      // Added: keep table header text readable against the colored heading row in both light and dark mode.
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onPrimary,
    );

    // Added: wrap the data table in a rounded card so it visually matches the reference image.
    return Container(
      decoration: AppThemeHelper.panelDecoration(context),
      child: Theme(
        // Added: lightly tune card/table colors without disturbing the rest of the app theme.
        data: Theme.of(context).copyWith(
          dividerColor: AppThemeHelper.borderColor(context),
        ),
        child: PaginatedDataTable(
          // Added: use a compact header row height closer to the screenshot.
          headingRowHeight: 52,
          // Added: use the bold purple header bar from the design reference.
          headingRowColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
          showEmptyRows: false,
          columns: [
            DataColumn(label: Text('Course', style: headingStyle)),
            DataColumn(label: Text('Assignment', style: headingStyle)),
            DataColumn(label: Text('Language', style: headingStyle)),
            DataColumn(label: Text('Status', style: headingStyle)),
            DataColumn(label: Text('Start Time', style: headingStyle)),
            DataColumn(label: Text('Finish Time / Duration', style: headingStyle)),
            DataColumn(label: Text('Action', style: headingStyle)),
          ],
          source: dataSource,
          // Added: show three rows like the target mockup while still supporting more via pagination.
          rowsPerPage: evaluationResults.isEmpty
              ? 3
              : evaluationResults.length < 3
                  ? evaluationResults.length
                  : 3,
          columnSpacing: 24,
          dataRowMinHeight: 76,
          dataRowMaxHeight: 76,
          horizontalMargin: 16,
          showCheckboxColumn: false,
          // Added: keep the page controls unobtrusive.
          arrowHeadColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class ProgramAssessmentState extends State<ProgramAssessmentView> {
  final lmsService = LmsFactory.getLmsService();
  final codeEvalUrl = LocalStorageService.getCodeEvalUrl();
  final _assessmentService = ProgramAssessmentService();

  List<Course> _courses = [];
  List<ProrgramAssessmentJob> _evaluationResults = [];

  // Added: cache the initial page load so repeated rebuilds do not refetch immediately.
  late Future<void> _initialLoadFuture;
  // Added: keep a timer so the page automatically refreshes running jobs.
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Added: load the table once when the screen opens.
    _initialLoadFuture = _loadData();
    // Added: automatically refresh every 20 seconds so running assessments eventually finish on screen.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      // Added: skip auto-refresh when the widget is no longer visible.
      if (!mounted) return;
      // Added: quietly refresh the table contents in the background.
      await _refreshEvaluations(showFeedback: false);
    });
  }

  @override
  void dispose() {
    // Added: cancel the timer to avoid memory leaks when leaving the page.
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<List<Course>> _fetch() async {
    // Added: fetch all courses for the current educator.
    _courses = await lmsService.getUserCourses();

    // Added: load assignments for every course so the table and form can resolve assignment names correctly.
    for (final course in _courses) {
      try {
        // Added: populate each course's assignments before rendering the program assessment UI.
        await course.refreshEssays();
      } catch (_) {
        // Added: tolerate a single course failure instead of breaking the whole view.
      }
    }

    return _courses;
  }

  // Added: get code evaluations for the current teacher.
  Future<List<ProrgramAssessmentJob>> _getEvaluations(String username) async {
    // Added: fetch the teacher's program assessment jobs from the service layer.
    _evaluationResults = await _assessmentService.getEvaluations(username);
    // Added: show the newest assessments first so the latest activity appears at the top.
    _evaluationResults.sort((a, b) => b.startTime.compareTo(a.startTime));
    return _evaluationResults;
  }

  // Added: load both courses and evaluation jobs together for the first render.
  Future<void> _loadData() async {
    await Future.wait([
      _fetch(),
      _getEvaluations(lmsService.userName ?? ''),
    ]);
  }

  Future<void> _refreshEvaluations({bool showFeedback = true}) async {
    // Added: refresh only the evaluations list to keep the refresh button responsive.
    await _getEvaluations(lmsService.userName ?? '');
    // Added: trigger a rebuild with the latest data.
    if (mounted) {
      setState(() {});
    }

    if (showFeedback) {
      // Added: confirm that a manual refresh succeeded.
      _showSnackBar(
        const SnackBar(content: Text('Program assessments refreshed.')),
      );
    }
  }

  // Added: helper to show status messages.
  void _showSnackBar(SnackBar snackBar) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  // Added: count finished jobs for a quick dashboard summary.
  int get _finishedCount =>
      _evaluationResults.where((job) => job.status == 'JOB FINISHED').length;

  // Added: count running jobs for a quick dashboard summary.
  int get _runningCount =>
      _evaluationResults.where((job) => job.status != 'JOB FINISHED').length;

  // Added: count locally cached fallback jobs for a quick dashboard summary.
  int get _fallbackCount =>
      _evaluationResults.where((job) => job.source == 'local').length;

  // Added: build a small desktop summary card above the table.
  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppThemeHelper.panelDecoration(context).copyWith(
          // Added: make summary cards slightly more opaque so the counts remain readable in dark mode.
          color: AppThemeHelper.isDark(context)
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.92)
              : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppThemeHelper.tint(context),
              foregroundColor: const Color(0xFF7C4DFF),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppThemeHelper.titleColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: AppThemeHelper.bodyColor(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Added: create the pill-shaped primary button from the reference design.
  Widget _buildCreateButton(VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      label: const Text(
        'New Assessment Job',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.add, size: 18),
    );
  }

  // Added: build a lighter secondary refresh button.
  Widget _buildRefreshButton() {
    return ElevatedButton(
      onPressed: () async {
        // Added: run the manual refresh flow when the educator clicks refresh.
        await _refreshEvaluations();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppThemeHelper.tint(context),
        foregroundColor: const Color(0xFF6A1B9A),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: const Text('Refresh'),
    );
  }

  // Added: explain when the page is using local fallback storage instead of the backend.
  Widget _buildFallbackBanner() {
    final usingFallback =
        codeEvalUrl.trim().isEmpty || _evaluationResults.any((job) => job.source == 'local');

    if (!usingFallback) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeHelper.isDark(context)
            ? const Color(0xFF3B3320)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppThemeHelper.isDark(context)
              ? const Color(0xFFD4B96E)
              : const Color(0xFFFFE082),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppThemeHelper.isDark(context)
                ? const Color(0xFFFFE082)
                : const Color(0xFF8D6E63),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Program Assessment fallback mode is active. EduLense can still create, refresh, and delete assessment jobs locally even when the code evaluation backend returns HTML or is not configured.',
              style: TextStyle(
                color: AppThemeHelper.isDark(context)
                    ? const Color(0xFFFFF3C4)
                    : const Color(0xFF5D4B28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'Program Assessment',
        userprofileurl: lmsService.profileImage ?? '',
      ),
      body: FutureBuilder<void>(
        future: _initialLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: _buildMainLayout(),
          );
        },
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFallbackBanner(),
        Row(
          children: [
            _buildCreateButton(() {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProgramAssessmentForm(
                    evaluationResults: _evaluationResults,
                    courses: _courses,
                    onEvaluationStarted: (
                      course,
                      assignment,
                      expectedOutput,
                    ) async {
                      // Added: refresh the table immediately after a new job starts.
                      await _refreshEvaluations(showFeedback: false);
                    },
                  ),
                ),
              );
            }),
            const SizedBox(width: 12),
            _buildRefreshButton(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildSummaryCard(
              icon: Icons.article_outlined,
              label: 'Total Jobs',
              value: _evaluationResults.length.toString(),
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              icon: Icons.play_circle_outline,
              label: 'Running',
              value: _runningCount.toString(),
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              icon: Icons.check_circle_outline,
              label: 'Finished',
              value: _finishedCount.toString(),
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              icon: Icons.cloud_off_outlined,
              label: 'Fallback Jobs',
              value: _fallbackCount.toString(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _evaluationResults.isEmpty
              ? Container(
                  decoration: AppThemeHelper.panelDecoration(context).copyWith(
                    // Added: keep the empty-state card readable and distinct in dark mode.
                    color: AppThemeHelper.isDark(context)
                        ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.92)
                        : Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      'No program assessments yet. Start a new assessment job to populate this table.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppThemeHelper.bodyColor(context)),
                    ),
                  ),
                )
              : EvaluationTable(
                  evaluationResults: _evaluationResults,
                  courses: _courses,
                  lmsService: lmsService,
                  onDelete: (course, assignment, job) async {
                    final deleteSuccessful = await ProgramAssessmentService()
                        .deleteEvaluation(
                      course: course,
                      assignment: assignment,
                      username: LmsFactory.getLmsService().userName ?? '',
                    );

                    if (deleteSuccessful) {
                      _showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green[700],
                          content: const Text('Evaluation removed successfully'),
                        ),
                      );
                    } else {
                      _showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red[700],
                          content: const Text('Unable to remove evaluation'),
                        ),
                      );
                    }

                    await _refreshEvaluations(showFeedback: false);
                  },
                ),
        ),
      ],
    );
  }
}
