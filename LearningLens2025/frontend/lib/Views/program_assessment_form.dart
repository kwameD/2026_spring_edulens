import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';
import 'package:learninglens_app/beans/assignment.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/services/local_storage_service.dart';
import 'package:learninglens_app/services/program_assessment_service.dart';

class ProgramAssessmentForm extends StatefulWidget {
  final List<Course> courses;
  final List<ProrgramAssessmentJob> evaluationResults;

  // Callback that is called when a new program evaluation is created successfully
  final Future<void> Function(
          Course course, Assignment assignment, String expectedOutput)?
      onEvaluationStarted;
  const ProgramAssessmentForm(
      {super.key,
      required this.courses,
      required this.onEvaluationStarted,
      required this.evaluationResults});

  @override
  _ProgramAssessmentFormState createState() => _ProgramAssessmentFormState(
      courses, onEvaluationStarted, evaluationResults);
}

class _ProgramAssessmentFormState extends State<ProgramAssessmentForm> {
  final lmsService = LmsFactory.getLmsService();
  final codeEvalUrl = LocalStorageService.getCodeEvalUrl();
  final _assessmentService = ProgramAssessmentService();
  final List<ProrgramAssessmentJob> evaluationResults;

  List<Course> courses = [];

  /// Program arguments
  final TextEditingController argsController = TextEditingController();
  final TextEditingController outputController = TextEditingController();
  final TextEditingController timeoutController = TextEditingController();
  final Future<void> Function(
          Course course, Assignment assignment, String expectedOutput)?
      onEvaluationStarted;
  final List<String> languages = ['C', 'C++', 'Java', 'Python'];

  Course? selectedCourse;
  Assignment? selectedAssignment;
  String? selectedLanguage;

  /// File containing the expected input
  PlatformFile? inputFile;

  /// File containing the expected output
  PlatformFile? outputFile;

  bool _isLoading = false;

  _ProgramAssessmentFormState(
      this.courses, this.onEvaluationStarted, this.evaluationResults);

  // Helper to check if form is valid
  bool get isFormValid =>
      selectedCourse != null &&
      selectedAssignment != null &&
      selectedLanguage != null &&
      outputFile != null &&
      timeoutController.text.trim().isNotEmpty;

  // Added: expose the selected course assignments safely for the dropdown.
  List<Assignment> get _selectedCourseAssignments => selectedCourse?.essays ?? [];

  @override
  void initState() {
    super.initState();
    // Default timeout of 30 seconds
    timeoutController.text = '30';
    // Added: preselect the first supported language so the form is immediately usable.
    selectedLanguage = languages.first;
    // Added: rebuild the form whenever the timeout field changes so the create button state updates.
    timeoutController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    outputController.dispose();
    timeoutController.dispose();
    argsController.dispose();
    super.dispose();
  }

  // Helper to show status messages
  void _showSnackBar(SnackBar snackBar) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  // Added: read uploaded file contents in a web-safe and desktop-safe way.
  String _getFileContents(PlatformFile file) {
    if (kIsWeb) {
      return utf8.decode(file.bytes!.toList());
    }

    return File(file.path!).readAsStringSync();
  }

  Future<bool> isFilesValid() async {
    if (outputFile == null) return false;
    // Assumes file is utf-8 encoded
    if (inputFile != null) {
      final outputFileContent = _getFileContents(outputFile!);
      final inputFileContent = _getFileContents(inputFile!);
      final outputFileLineCount = outputFileContent.split('\n').length;
      final inputFileLineCount = inputFileContent.split('\n').length;
      if (outputFileLineCount != inputFileLineCount) {
        await _showLineCountMismatchDialog(
            context, inputFileLineCount, outputFileLineCount);
        return false;
      }
    }

    return true;
  }

  Future<void> _showLineCountMismatchDialog(BuildContext context,
      int inputFileLineCount, int outputFileLineCount) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Line Count Mismatch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'The number of lines in the expected input file ($inputFileLineCount) does not match '
            'the number of lines in the expected output file ($outputFileLineCount).',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmStart(Course course, Assignment assignment) async {
    final existingEvaluation = evaluationResults.firstWhereOrNull((result) =>
        result.assignmentId == assignment.id.toString() &&
        result.courseId == course.id.toString());

    if (existingEvaluation == null) {
      return true;
    }

    final confirmStart = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Start'),
          content: Text(
              'Starting a new assessment will overwrite an existing assessment for assignment "${assignment.name}"'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Start Assessment',
                style: TextStyle(color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmStart == null) {
      return false;
    }

    return confirmStart;
  }

  Future<void> _startEvaluation(
      Course course,
      Assignment assignment,
      String input,
      String expectedOutput,
      String language,
      int timeoutSeconds) async {
    // Maximum timeout cannot be more than 2 minutes
    if (timeoutSeconds > 120) {
      _showSnackBar(SnackBar(
          backgroundColor: Colors.red[700],
          content: const Text('Maximum timeout cannot be longer than 2 minutes')));
      return;
    }

    if (timeoutSeconds <= 0) {
      // Added: block invalid zero or negative values before hitting the backend.
      _showSnackBar(SnackBar(
          backgroundColor: Colors.red[700],
          content: const Text('Timeout must be at least 1 second.')));
      return;
    }

    if (!(await isFilesValid()) || !(await _confirmStart(course, assignment))) {
      return;
    }

    final response = await _assessmentService.startEvaluation(
        course: course,
        assignment: assignment,
        input: input,
        expectedOutput: expectedOutput,
        language: language,
        timeoutSeconds: timeoutSeconds);

    if (response.statusCode != 200) {
      _showSnackBar(SnackBar(
          backgroundColor: Colors.red[700],
          content: Text(
              'Unable to evaluate coding assignment: "${response.body}"')));

      debugPrint(response.body);
      return;
    }

    // Added: show a more specific success message when the service used local fallback mode.
    var successMessage = 'Evaluation started successfully. Check back in a few minutes.';
    try {
      final decodedResponse = jsonDecode(response.body);
      if (decodedResponse is Map<String, dynamic> &&
          decodedResponse['message'] != null) {
        successMessage = decodedResponse['message'].toString();
      }
    } catch (_) {
      // Added: keep the default success message when the response body is not JSON.
    }

    _showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text(successMessage),
      duration: const Duration(seconds: 8),
    ));

    if (onEvaluationStarted != null) {
      await onEvaluationStarted!(course, assignment, expectedOutput);
    }

    // Navigate back to previous page
    Navigator.of(context).pop();
  }

  // Added: fetch assignments lazily when a course is selected so the dropdown always has current data.
  Future<void> _handleCourseSelection(Course? value) async {
    if (value == null) {
      setState(() {
        // Added: clear dependent fields when the course is removed.
        selectedCourse = null;
        selectedAssignment = null;
      });
      return;
    }

    setState(() {
      // Added: show the selected course immediately in the UI.
      selectedCourse = value;
      // Added: reset the assignment because the course changed.
      selectedAssignment = null;
      // Added: show a loading state while assignments refresh.
      _isLoading = true;
    });

    try {
      // Added: refresh the latest assignments from the LMS for the selected course.
      await value.refreshEssays();
    } finally {
      if (mounted) {
        setState(() {
          // Added: end the temporary loading state after assignments finish loading.
          _isLoading = false;
        });
      }
    }
  }

  // Added: create a shared file picker button to keep the form layout consistent.
  Widget _buildFilePickerRow({
    required String buttonLabel,
    required PlatformFile? selectedFile,
    required ValueChanged<PlatformFile?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text(buttonLabel),
          onPressed: () async {
            // Added: limit uploads to txt files because the backend expects plain text cases.
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['txt'],
              withData: kIsWeb,
            );
            final file = result?.files.single;
            if (file == null) return;

            // Added: bubble the selected file back to the form state.
            onSelected(file);
          },
        ),
        if (selectedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F4FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6DDF0)),
            ),
            child: Text(selectedFile.name),
          ),
        if (selectedFile != null)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Added: allow educators to remove a selected test file without reloading the page.
              onSelected(null);
            },
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: 'New Assessment Job',
          userprofileurl: lmsService.profileImage ?? '',
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          return Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _buildForm(context)));
        }));
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6DDF0)),
        ),
        child: Form(
          child: Column(
            spacing: 14,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Program Assessment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const Text(
                'Choose a course, assignment, language, timeout, and expected outputs to launch a new automated code evaluation job.',
                style: TextStyle(color: Color(0xFF6B6573)),
              ),
              // Courses Dropdown
              DropdownButtonFormField<Course>(
                decoration: const InputDecoration(
                  labelText: 'Courses',
                  border: OutlineInputBorder(),
                ),
                value: selectedCourse,
                items: courses.map((course) {
                  return DropdownMenuItem(
                    value: course,
                    child: Text(course.fullName),
                  );
                }).toList(),
                onChanged: (value) async {
                  // Added: refresh assignments whenever a different course is chosen.
                  await _handleCourseSelection(value);
                },
              ),
              // Assignments Dropdown
              Opacity(
                opacity: selectedCourse == null ? 0.5 : 1,
                child: DropdownButtonFormField<Assignment>(
                  decoration: const InputDecoration(
                    labelText: 'Assignments',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedAssignment,
                  items: _selectedCourseAssignments.map((assignment) {
                    return DropdownMenuItem(
                      value: assignment,
                      child: Text(assignment.name),
                    );
                  }).toList(),
                  onChanged: selectedCourse == null
                      ? null
                      : (value) {
                          setState(() {
                            selectedAssignment = value;
                          });
                        },
                ),
              ),
              // Language selection dropdown
              DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedLanguage,
                  items: languages
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = value;
                    });
                  }),
              TextField(
                  controller: timeoutController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly, // Only allows digits
                    FilteringTextInputFormatter.allow(RegExp(
                        r'^[1-9][0-9]*$|^0$')) // Allows only positive nubmers and zero
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Program Execution Timeout (in seconds)',
                    border: OutlineInputBorder(),
                    helperText: 'Recommended: 30 seconds. Maximum: 120 seconds.',
                  )),
              const Text(
                'Note that students MUST submit a .zip file with the entry point of the program being in a file named entry.(c, cpp, java, py).',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildFilePickerRow(
                buttonLabel: 'Input File',
                selectedFile: inputFile,
                onSelected: (file) {
                  setState(() {
                    // Added: store or clear the optional input file.
                    inputFile = file;
                  });
                },
              ),
              _buildFilePickerRow(
                buttonLabel: 'Expected Output File',
                selectedFile: outputFile,
                onSelected: (file) {
                  setState(() {
                    // Added: store or clear the required expected output file.
                    outputFile = file;
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16), // bigger size
                    textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold), // bigger text
                    backgroundColor: const Color(0xFF7C4DFF), // primary color
                    foregroundColor: Colors.white, // text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // rounded corners
                    ),
                    elevation: 0,
                  ),
                  onPressed: null,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16), // bigger size
                    textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold), // bigger text
                    backgroundColor: const Color(0xFF7C4DFF), // primary color
                    foregroundColor: Colors.white, // text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // rounded corners
                    ),
                    elevation: 0,
                  ),
                  onPressed: !isFormValid
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            await _startEvaluation(
                                selectedCourse!,
                                selectedAssignment!,
                                inputFile != null
                                    ? _getFileContents(inputFile!)
                                    : '',
                                _getFileContents(outputFile!),
                                selectedLanguage!,
                                int.parse(timeoutController.text));
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  child: const Text('Create'),
                )
            ],
          ),
        ),
      ),
    );
  }
}
