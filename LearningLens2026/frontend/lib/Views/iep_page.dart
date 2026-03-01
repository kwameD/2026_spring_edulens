import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import "package:flutter/material.dart";
import 'package:intl/intl.dart';
import 'package:learninglens_app/Api/llm/DeepSeek_api.dart';
import 'package:learninglens_app/Api/llm/enum/llm_enum.dart';
import 'package:learninglens_app/Api/llm/grok_api.dart';
import 'package:learninglens_app/Api/llm/llm_api_modules_base.dart';
import 'package:learninglens_app/Api/llm/local_llm_service.dart'; // local llm
import 'package:learninglens_app/Api/llm/openai_api.dart';
import 'package:learninglens_app/Api/llm/perplexity_api.dart';
import "package:learninglens_app/Api/lms/factory/lms_factory.dart";
import "package:learninglens_app/Controller/custom_appbar.dart";
import 'package:learninglens_app/Controller/html_converter.dart';
import 'package:learninglens_app/beans/assessment.dart';
import 'package:learninglens_app/beans/assignment.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/beans/override.dart';
import 'package:learninglens_app/beans/participant.dart';
import 'package:learninglens_app/beans/quiz.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

class IepPage extends StatefulWidget {
  IepPage();

  @override
  State createState() {
    return _IepPageState();
  }
}

class _IepPageState extends State<IepPage> {
  final db = FirebaseFirestore.instance;
  bool? isChecked1 = false;
  bool? isChecked2 = false;
  String? selectedCourse;
  String? selectedCourseName;
  String? selectedparticipantName;
  String? selectedEssay;
  String? selectedGradeLevel;
  String? selectedDisability;
  String? iep;
  int? userId;
  int? courseId;
  String? fullname;
  int? newEndTime;
  String selectedDate = 'Select a Date';
  Future<List<Participant>>? participants;
  Future<List<Assessment>>? assignments;
  Assessment? selectedAssignment;
  int? epochTime;
  int? epochTime2;
  int? attempts;
  List<Override>? overrides = [];
  TextEditingController _attemptsController = TextEditingController();
  bool _isAIRecommending = false;
  TextEditingController iepSummaryController = TextEditingController();
  String iepSummary = "";
  TextEditingController iepRecommendation = TextEditingController();

  LlmType? selectedLLM;
  bool _localLlmAvail = !kIsWeb;
  bool canceled = false;

  List<String> gradeLevel = [
    "N/A",
    "Kindergarden",
    "1st grade",
    "2nd grade",
    "3rd grade",
    "4th grade",
    "5th grade",
    "6th grade",
    "7th grade",
    "8th grade",
    "9th grade",
    "10th grade",
    "11th grade",
    "12h grade",
  ];
  List<String> disabilityCategories = [
    "Autism Spectrum Disorder",
    "Specific Learning Disability",
    "Speech or Language Impairment",
    "Intellectual Disability",
    "Emotional Disturbance",
    "Multiple Disabilities",
    "Hearing Impairment",
    "Visual Impairment",
    "Deaf-Blindness",
    "Orthopedic Impairment",
    "Traumatic Brain Injury",
    "Other Health Impairment",
  ];

  @override
  void initState() {
    super.initState();
    overrides = LmsFactory.getLmsService().overrides;
    overrides?.sort((a, b) => a.fullname.compareTo(b.fullname));
    selectedLLM = LlmType.values
        .firstWhereOrNull((llm) => LocalStorageService.userHasLlmKey(llm));
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: epochTime != null
          ? DateTime.fromMillisecondsSinceEpoch(epochTime!.toInt() * 1000)
          : selectedAssignment!.dueDate ?? DateTime.now(),
      firstDate: selectedAssignment!.dueDate ?? DateTime.now(),
      lastDate: epochTime2 != null && selectedAssignment!.type == "essay"
          ? DateTime.fromMillisecondsSinceEpoch(epochTime2! * 1000)
          : DateTime(2100),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        epochTime = (picked.millisecondsSinceEpoch / 1000).round();
      });
    }
  }

  // void _getAssignmentOverride() async { ***** Not used *****
  //   await MoodleLmsService().getAssignmentOverrides();
  // }

  // Function to show details in a dialog
  void _showDetailsDialog(BuildContext context, Override override) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Details"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Student Name: ${override.fullname}"),
                Text("Course Name: ${override.courseName}"),
                Text(
                    "Assignment: ${override.type}: ${override.assignmentName}"),
                Text(""
                    //"Extended Due Date: ${formatDate(override.endTime?.toString())}"
                    ),
                Text(""
                    //"Cut Off Date: ${formatDate(override.cutoffTime?.toString())}"
                    ),
                Text("Attempts: ${override.attempts?.toString() ?? 'N/A'}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        appBar: CustomAppBar(
          title: 'Individual Education Plans',
          onRefresh: () {
            // _loadCourses();
          },
          userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 400,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Individual Education Plan',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Enroll Student in New IEP',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    DropdownMenu<Course>(
                      label: Text('Course'),
                      hintText: 'Select Course',
                      width: 350,
                      dropdownMenuEntries:
                          (getAllCourses() ?? []).map((Course course) {
                        return DropdownMenuEntry<Course>(
                          value: course,
                          label: course.fullName,
                        );
                      }).toList(),
                      onSelected: (Course? selectedValue) {
                        setState(() {
                          selectedCourseName = selectedValue?.fullName;
                          courseId = selectedValue!.id;
                        });
                        participants =
                            handleSelection(selectedValue?.id.toString());
                        resetForm(true);
                      },
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<List<Participant>>(
                        future: participants,
                        builder: (BuildContext context,
                            AsyncSnapshot<List<Participant>> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else {
                            List<DropdownMenuEntry<Participant>>
                                dropdownEntries =
                                snapshot.data?.map((Participant participant) {
                                      return DropdownMenuEntry<Participant>(
                                        value: participant,
                                        label: participant.fullname,
                                      );
                                    }).toList() ??
                                    [];
                            return DropdownMenu(
                              enabled: snapshot.hasData,
                              label: Text('Participants'),
                              // helperText: 'Participants',
                              hintText: 'Select Participants',
                              width: 350,
                              dropdownMenuEntries: dropdownEntries,
                              onSelected: (Participant? selectedParticipant) {
                                setState(() {
                                  if (selectedParticipant != null) {
                                    userId = selectedParticipant.id;
                                    fullname =
                                        selectedParticipant.fullname.toString();
                                  } else {
                                    print('No Participants were selected');
                                  }
                                });
                                resetForm(true);
                              },
                            );
                          }
                        }),
                    SizedBox(height: 20),
                    DropdownMenu(
                      enabled: true,
                      label: Text('Grade Level'),
                      // helperText: 'Essays',
                      hintText: 'Select grade level',
                      width: 350,
                      dropdownMenuEntries: gradeLevel
                          .map((value) => DropdownMenuEntry<String>(
                                value: value,
                                label: value,
                              ))
                          .toList(),
                      onSelected: (String? selectedGrade) {
                        setState(() {
                          selectedGradeLevel = selectedGrade;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    DropdownMenu(
                      enabled: true,
                      label: Text('Disability'),
                      // helperText: 'Essays',
                      hintText: 'Select disability',
                      width: 350,
                      dropdownMenuEntries: disabilityCategories
                          .map((value) => DropdownMenuEntry<String>(
                                value: value,
                                label: value,
                              ))
                          .toList(),
                      onSelected: (String? disability) {
                        setState(() {
                          selectedDisability = disability;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Opacity(
                            opacity:
                                selectedAssignment != null && userId != null
                                    ? 1
                                    : .5,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black),
                              ),
                              child: Text(
                                epochTime == null
                                    ? ""
                                    : DateFormat.yMd().format(
                                        DateTime.fromMillisecondsSinceEpoch(
                                            epochTime! * 1000)),
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: () => _selectDate(context),
                            child: Text('Select Due Date'),
                          ),
                        ),
                      ],
                    ),
                    // FutureBuilder<List<Assessment>>(
                    //     future: assignments,
                    //     builder: (BuildContext context,
                    //         AsyncSnapshot<List<Assessment>> snapshot) {
                    //       if (snapshot.connectionState ==
                    //           ConnectionState.waiting) {
                    //         return CircularProgressIndicator();
                    //       } else if (snapshot.hasError) {
                    //         return Text('Error: ${snapshot.error}');
                    //       } else {
                    //         List<DropdownMenuEntry<Assessment>>
                    //             dropdownEntries =
                    //             snapshot.data?.map((Assessment assignment) {
                    //                   return DropdownMenuEntry<Assessment>(
                    //                     value: assignment,
                    //                     label:
                    //                         "${assignment.name} (${assignment.type.toUpperCase()})",
                    //                   );
                    //                 }).toList() ??
                    //                 [];
                    //         return DropdownMenu(
                    //           enabled: snapshot.hasData,
                    //           label: Text('Assignment'),
                    //           // helperText: 'Essays',
                    //           hintText: 'Select Assignment',
                    //           width: 350,
                    //           dropdownMenuEntries: dropdownEntries,
                    //           onSelected: (Assessment? selectedAssessment) {
                    //             setState(() {
                    //               if (selectedAssessment != null) {
                    //                 selectedAssignment = selectedAssessment;
                    //                 if (selectedAssessment.type == "essay") {
                    //                   _attemptsController.value =
                    //                       TextEditingValue.empty;
                    //                   attempts = null;
                    //                 } else {
                    //                   epochTime2 = null;
                    //                 }
                    //                 resetForm(false);
                    //               } else {
                    //                 print('Assessment was Null');
                    //               }
                    //             });
                    //           },
                    //         );
                    //       }
                    //     }),
                    SizedBox(height: 10),
                    SizedBox(
                        width: 350,
                        child: TextField(
                          enabled: userId != null,
                          decoration: InputDecoration(
                              alignLabelWithHint: true,
                              labelText: "Things the student already knows",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              )),
                          controller: iepSummaryController,
                          onChanged: (value) => setState(() {
                            iepSummary = value;
                          }),
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          minLines: 10,
                          maxLines: 10,
                        )),
                    SizedBox(height: 10),
                    SizedBox(
                        width: 350,
                        child: Align(
                            alignment: AlignmentGeometry.topRight,
                            child: Text("LLM: "))),
                    SizedBox(
                        width: 350,
                        child: Align(
                            alignment: AlignmentGeometry.topRight,
                            child: DropdownButton<LlmType>(
                                value: selectedLLM,
                                onChanged: (LlmType? newValue) {
                                  setState(() {
                                    selectedLLM = newValue;
                                  });
                                },
                                items: LlmType.values.map((LlmType llm) {
                                  return DropdownMenuItem<LlmType>(
                                    value: llm,
                                    enabled: (llm == LlmType.LOCAL &&
                                            LocalStorageService
                                                    .getLocalLLMPath() !=
                                                "" &&
                                            _localLlmAvail) ||
                                        LocalStorageService.userHasLlmKey(llm),
                                    child: Text(
                                      llm.displayName,
                                      style: TextStyle(
                                        color: (llm == LlmType.LOCAL &&
                                                    LocalStorageService
                                                            .getLocalLLMPath() !=
                                                        "" &&
                                                    _localLlmAvail) ||
                                                LocalStorageService
                                                    .userHasLlmKey(llm)
                                            ? Colors.black87
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                }).toList()))),
                    if (selectedLLM == LlmType.LOCAL) ...[
                      const SizedBox(
                          width: 350,
                          child: Align(
                            alignment: AlignmentGeometry.topRight,
                            child: Text(
                              "Running a Large Language Model (LLM) locally typically requires substantial hardware resources.\nThe recommended model for this task is 7B or higher reasoning models (Qwen). Using smaller models may produce inaccurate or misleading responses.\nFor best results, we recommend using the external LLM.\nPlease use the local LLM responsibly and independently verify any critical information.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          )),
                    ],
                    SizedBox(
                      width: 350,
                      child: Align(
                        alignment: AlignmentGeometry.topRight,
                        child: ElevatedButton(
                          onPressed: userId != null &&
                                  iepSummary.isNotEmpty &&
                                  selectedLLM != null &&
                                  selectedGradeLevel != null &&
                                  selectedDisability != null &&
                                  selectedCourseName != null
                              ? () => recommendIEP()
                              : null,
                          child: _isAIRecommending
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    if (selectedLLM == LlmType.LOCAL)
                                      TextButton(
                                        onPressed: () async {
                                          bool decision = await LocalLLMService()
                                              .showCancelConfirmationDialog();
                                          if (decision) {
                                            canceled = true;
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text(
                                          'Cancel Generation',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                )
                              : const Text('IEP Preview'),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 350,
                        child: TextField(
                          decoration: InputDecoration(
                              alignLabelWithHint: true,
                              enabled: iepRecommendation.value.text.isNotEmpty,
                              labelText: "IEP Recommendations",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              )),
                          controller: iepRecommendation,
                          readOnly: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          minLines: 10,
                          maxLines: 10,
                        )),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.only(top: 10, left: 160, bottom: 20),
                      child: ElevatedButton(
                        onPressed: () async {
                          await addIEP(
                              selectedGradeLevel!,
                              courseId!,
                              selectedCourseName!,
                              userId!,
                              fullname!,
                              selectedDisability!,
                              iepSummary,
                              iep!);
                          resetForm(false);
                        },
                        child: Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Existing IEPs',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('IEP')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;

                        return SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal, // allows horizontal scrolling
                          child: SingleChildScrollView(
                            scrollDirection:
                                Axis.vertical, // allows vertical scrolling
                            child: DataTable(
                              columnSpacing: 40,
                              headingRowColor: MaterialStateProperty.all(
                                Colors.grey.shade200,
                              ),
                              columns: const [
                                DataColumn(label: Text('Student Name')),
                                DataColumn(label: Text('Course Name')),
                                DataColumn(label: Text('Grade Level')),
                                DataColumn(label: Text('Disability')),
                                DataColumn(label: Text('Score')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(data['fullName'] ?? '')),
                                    DataCell(Text(data['courseName'] ?? '')),
                                    DataCell(Text(data['gradeLevel'] ?? '')),
                                    DataCell(Text(data['disability'] ?? '')),
                                    DataCell(Text(
                                      data['score']?.toString() ?? '',
                                    )),
                                    DataCell(
                                      ElevatedButton(
                                        onPressed: () {
                                          final docId = doc.id;

                                          print("Viewing IEP: $docId");

                                          // Option 1: Navigate to a detail page
                                          // Navigator.push(
                                          //   context,
                                          //   MaterialPageRoute(
                                          //     builder: (_) => IEPDetailPage(
                                          //       documentId: docId,
                                          //     ),
                                          //   ),
                                          // );

                                          // Option 2 (alternative): Show dialog instead
                                          // showDialog(...)
                                        },
                                        child: const Text("View"),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  List<Course>? getAllCourses() {
    List<Course>? result;
    result = LmsFactory.getLmsService().courses;
    return result;
  }

  Future<List<Participant>>? getAllParticipants(String courseID) async {
    List<Participant>? participants;
    participants =
        await LmsFactory.getLmsService().getCourseParticipants(courseID);
    return participants;
  }

  Future<List<Participant>> handleSelection(String? courseID) async {
    if (courseID != null) {
      List<Participant>? participants = await getAllParticipants(courseID);
      if (participants == null) {
        return [];
      } else {
        return participants;
      }
    } else {
      print('Course ID was Null.');
      return [];
    }
  }

  Future<List<Assessment>> handleAssessmentSelection(int? courseID) async {
    if (courseID != null) {
      List<Assignment> essayList =
          await LmsFactory.getLmsService().getEssays(courseID);
      // Fetch quizzes (if available).
      List<Quiz> quizList = [];
      try {
        quizList = await LmsFactory.getLmsService().getQuizzes(courseID);
      } catch (e) {
        print("getQuizzes not available or failed: $e");
      }
      // Combine them into one list
      List<Assessment> assessments = [
        ...essayList.map((a) => Assessment(assessment: a, type: "essay")),
        ...quizList.map((q) => Assessment(assessment: q, type: "quiz"))
      ];
      if (assessments.isNotEmpty) {
        return assessments;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  void resetForm(bool clearIEPSummary) {
    setState(() {
      epochTime = null;
      epochTime2 = null;
      if (clearIEPSummary) {
        iepSummaryController.value = TextEditingValue.empty;
        iepSummary = "";
      }
      iepRecommendation.value = TextEditingValue.empty;
      _attemptsController.value = TextEditingValue.empty;
      attempts = null;
    });
  }

  Future<void> addIEP(
      String gradeLevel,
      int courseId,
      String courseName,
      int userId,
      String fullName,
      String disability,
      String iepSummary,
      String iep) async {
    print(
        "Add IEP: grade level: $gradeLevel, courseId $courseId, userId $userId, disability $disability, iep summary $iepSummary, iep $iep");
    try {
      // Create a map of data
      final user = <String, dynamic>{
        "courseId": courseId,
        "userId": userId,
        "fullName": fullname,
        "gradeLevel": gradeLevel,
        "disability": disability,
        "courseName": courseName,
        "iepSummary": iepSummary,
        "iep": iep,
      };

      db
          .collection("IEP")
          .add(user)
          .then((DocumentReference doc) =>
              print('DocumentSnapshot added with ID: ${doc.id}'))
          .catchError((error) => print("Failed to add user: $error"));

      setState(() {
        // updates the user interface
        overrides = LmsFactory.getLmsService().overrides;
        overrides?.sort((a, b) => a.fullname.compareTo(b.fullname));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully created essay IEP.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating override: $e")),
      );
    }
  }

  String formatDate(String? dateString) {
    if (dateString == null) {
      return 'N/A';
    }
    DateFormat dateFormat = DateFormat('MMM d yyyy hh:mm a');
    return dateFormat.format(DateTime.parse(dateString));
  }

  Future<void> recommendIEP() async {
    if (selectedLLM == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "No AI credentials found. Please log in to an AI platform.")),
      );
      return;
    }
    setState(() {
      _isAIRecommending = true;
    });
    LLM aiModel;
    if (selectedLLM == LlmType.CHATGPT) {
      aiModel = OpenAiLLM(LocalStorageService.getOpenAIKey());
    } else if (selectedLLM == LlmType.GROK) {
      aiModel = GrokLLM(LocalStorageService.getGrokKey());
    } else if (selectedLLM == LlmType.DEEPSEEK) {
      aiModel = DeepseekLLM(LocalStorageService.getDeepseekKey());
    } else if (selectedLLM == LlmType.LOCAL) {
      aiModel = LocalLLMService();
    } else {
      aiModel = PerplexityLLM(LocalStorageService.getPerplexityKey());
    }

    String prompt1 =
        "Write an IEP for student $fullname that has $selectedDisability, is in the $selectedGradeLevel, and lives in New York City for $selectedCourseName. This are the things the student already knowns in the subject: $iepSummary";

    String summary = "";
    DateTime? due;
    DateTime? deadline;
    int? newAttempts;

    if (selectedLLM != LlmType.LOCAL ||
        await LocalLLMService().checkIfLoadedLocalLLMRecommended()) {
      try {
        var result =
            await aiModel.postToLlm(HtmlConverter.convert(prompt1) ?? "");

        print("results: $result");

        summary = result;
        iep = result;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during AI analysis: $e")),
        );
      }
    }
    setState(() {
      _isAIRecommending = false;
      setState(() {
        iepRecommendation.value = TextEditingValue(text: summary);
      });
    });
  }
}
