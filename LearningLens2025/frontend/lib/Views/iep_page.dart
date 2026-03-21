import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import "package:flutter/material.dart";
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'package:learninglens_app/Views/iep_detail_page.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/beans/override.dart';
import 'package:learninglens_app/beans/participant.dart';
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
  String? selectedCourse;
  String? selectedCourseName;
  String? selectedparticipantName;

  String? errorMessage;
  int? userId;
  int? courseId;
  String? fullname;
  Future<List<Participant>>? participants;
  List<Override>? overrides = [];

  TextEditingController _dueDateController = TextEditingController();
  TextEditingController studentKnowledgeController = TextEditingController();
  TextEditingController disabilityController = TextEditingController();
  TextEditingController courseController = TextEditingController();
  TextEditingController gradeLevelController = TextEditingController();
  TextEditingController iepRecommendationController = TextEditingController();

  bool _isAIRecommending = false;
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
    "12th grade",
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

  @override
  void dispose() {
    _dueDateController.dispose();
    studentKnowledgeController.dispose();
    disabilityController.dispose();
    courseController.dispose();
    gradeLevelController.dispose();
    iepRecommendationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = picked.toString().split(" ")[0];
      });
    }
  }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1000) {
            // Small screen → stack vertically
            return Column(
              children: [
                SizedBox(
                  height: 700,
                  child: _leftPanel(),
                ),
                Expanded(
                  child: _rightPanel(),
                ),
              ],
            );
          } else {
            // Large screen → side by side
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: _leftPanel(),
                ),
                Expanded(
                  child: _rightPanel(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Column _rightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Existing IEPs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('IEP').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal, // allows horizontal scrolling
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical, // allows vertical scrolling
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
                      DataColumn(label: Text('Due Date')),
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
                          DataCell(Text(data['dueDate'] ?? '')),
                          DataCell(
                            ElevatedButton(
                              onPressed: () {
                                final docId = doc.id;

                                print("Viewing IEP: $docId");

                                //Navigate to a detail page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IepDetailPage(
                                      documentId: doc.id,
                                    ),
                                  ),
                                );
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
    );
  }

  SingleChildScrollView _leftPanel() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Individual Education Plan',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          Text(
            'Enroll Student in New IEP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // course select button
          DropdownMenu<Course>(
            label: Text('Course'),
            hintText: 'Select Course',
            width: 350,
            controller: courseController,
            dropdownMenuEntries: (getAllCourses() ?? []).map((Course course) {
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
              participants = handleSelection(selectedValue?.id.toString());
            },
          ),
          // end of course select buttoin
          SizedBox(height: 10),
          // participant select button
          FutureBuilder<List<Participant>>(
              future: participants,
              builder: (BuildContext context,
                  AsyncSnapshot<List<Participant>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  List<DropdownMenuEntry<Participant>> dropdownEntries =
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
                    //controller: participantController,
                    dropdownMenuEntries: dropdownEntries,
                    onSelected: (Participant? selectedParticipant) {
                      setState(() {
                        if (selectedParticipant != null) {
                          userId = selectedParticipant.id;
                          fullname = selectedParticipant.fullname.toString();
                        } else {
                          print('No Participants were selected');
                        }
                      });
                    },
                  );
                }
              }),
          // end of participant select button
          SizedBox(height: 20),
          // grade level button
          DropdownMenu(
            enabled: true,
            label: Text('Grade Level'),
            // helperText: 'Essays',
            hintText: 'Select grade level',
            width: 350,
            controller: gradeLevelController,
            dropdownMenuEntries: gradeLevel
                .map((value) => DropdownMenuEntry<String>(
                      value: value,
                      label: value,
                    ))
                .toList(),
          ),
          // end of grade level button
          SizedBox(height: 10),
          // disability button
          DropdownMenu(
            enabled: true,
            label: Text('Disability'),
            // helperText: 'Essays',
            hintText: 'Select disability',
            width: 350,
            controller: disabilityController,
            dropdownMenuEntries: disabilityCategories
                .map((value) => DropdownMenuEntry<String>(
                      value: value,
                      label: value,
                    ))
                .toList(),
          ),
          // end of disability button
          SizedBox(height: 10),
          SizedBox(
            width: 350,
            child: TextField(
              controller: _dueDateController,
              decoration: const InputDecoration(
                labelText: 'Due Date',
                filled: true,
                prefixIcon: Icon(Icons.calendar_today),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
              readOnly: true,
              onTap: () => _selectDate(),
            ),
          ),
          // end of due date button
          SizedBox(height: 10),
          // student knowledge textarea
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
              controller: studentKnowledgeController,
              maxLength: 500,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              minLines: 10,
              maxLines: 10,
            ),
          ),
          // end of student knowledge textarea
          SizedBox(height: 10),
          // llm select button
          SizedBox(
              width: 350,
              child: Align(
                  alignment: AlignmentGeometry.topRight, child: Text("LLM: "))),
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
                                  LocalStorageService.getLocalLLMPath() != "" &&
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
                                      LocalStorageService.userHasLlmKey(llm)
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
              ),
            ),
          ],
          // end of select llm button
          // iep preview button
          SizedBox(
            width: 350,
            child: Align(
              alignment: AlignmentGeometry.topRight,
              child: ElevatedButton(
                onPressed: userId != null &&
                        studentKnowledgeController.text.isNotEmpty &&
                        selectedLLM != null &&
                        gradeLevelController.text.isNotEmpty &&
                        disabilityController.text.isNotEmpty &&
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                                    fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      )
                    : const Text('IEP Preview'),
              ),
            ),
          ),
          Text("IEP Preview"),
          Divider(color: Colors.black),
          // end of iep preview
          // iep recommendation text area
          SizedBox(
            width: 350,
            height: 250,
            child: Markdown(
              data: iepRecommendationController.text,
            ),
          ),
          Divider(color: Colors.black),
          // end of iep recommendation text area
          SizedBox(height: 10),
          // submit button
          Container(
            padding: EdgeInsets.only(top: 10, left: 160, bottom: 20),
            child: ElevatedButton(
              onPressed: () async {
                // check to see if all fields are filled out
                if (_dueDateController.text.isNotEmpty &&
                    studentKnowledgeController.text.isNotEmpty &&
                    disabilityController.text.isNotEmpty &&
                    courseController.text.isNotEmpty &&
                    gradeLevelController.text.isNotEmpty &&
                    // participantController.text.isNotEmpty &&
                    iepRecommendationController.text.isNotEmpty) {
                  await addIEP(
                      gradeLevelController.text,
                      courseId!,
                      selectedCourseName!,
                      userId!,
                      fullname!,
                      disabilityController.text,
                      studentKnowledgeController.text,
                      iepRecommendationController.text,
                      _dueDateController.text);
                  resetForm(true);
                  setState(() {
                    errorMessage = "";
                  });
                } else {
                  setState(() {
                    errorMessage = "All fields must be filled out.";
                  });
                }
              },
              child: Text('Submit'),
            ),
          ),
          // end of submit button
          Center(
            child: Text(
              errorMessage ?? "",
              style: TextStyle(color: Colors.red),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

// get list of coruses
  List<Course>? getAllCourses() {
    List<Course>? result = LmsFactory.getLmsService().courses;
    return result;
  }

  // get list of participants
  Future<List<Participant>>? getAllParticipants(String courseID) async {
    List<Participant>? participants =
        await LmsFactory.getLmsService().getCourseParticipants(courseID);
    return participants;
  }

  // get list of participants based on course Id
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

  void resetForm(bool clearIEPSummary) {
    setState(() {
      if (clearIEPSummary) {
        print(_dueDateController.text);
        setState(() {
          _dueDateController.clear();
          _dueDateController.clear();
          studentKnowledgeController.clear();
          disabilityController.clear();
          courseController.clear();
          gradeLevelController.clear();
          iepRecommendationController.clear();
        });
      }
    });
  }

  Future<void> addIEP(
      String gradeLevel,
      int courseId,
      String courseName,
      int userId,
      String fullName,
      String disability,
      String studentKnowledge,
      String iep,
      String dueDate) async {
    try {
      // Create a map of data
      final user = <String, dynamic>{
        "courseId": courseId,
        "userId": userId,
        "fullName": fullname,
        "gradeLevel": gradeLevel,
        "disability": disability,
        "courseName": courseName,
        "studentKnowledge": studentKnowledge,
        "iep": iep,
        "dueDate": dueDate,
      };

      // add iep to firebase database
      db
          .collection("IEP")
          .add(user)
          .then((DocumentReference doc) =>
              print('DocumentSnapshot added with ID: ${doc.id}'))
          .catchError((error) => print("Failed to add user: $error"));

      // show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully created essay IEP.")),
      );
    } catch (e) {
      // show error message
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
    // gets the api key based on the selected LLM
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

    // prompt that is sent to the llm
    String prompt =
        "Write an IEP for student $fullname that has ${disabilityController.text}, is in the ${gradeLevelController.text}, and lives in New York City for $selectedCourseName. This are the things the student already knowns in the subject: ${studentKnowledgeController.text}. This iep is due on ${_dueDateController.text}";

    String summary = "";

    if (selectedLLM != LlmType.LOCAL ||
        await LocalLLMService().checkIfLoadedLocalLLMRecommended()) {
      try {
        // submit prompt to LLM
        var result =
            await aiModel.postToLlm(HtmlConverter.convert(prompt) ?? "");

        summary = result;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during AI analysis: $e")),
        );
      }
    }
    setState(() {
      _isAIRecommending = false;
      setState(() {
        // display iep on iep recommendation text area
        iepRecommendationController.value = TextEditingValue(text: summary);
      });
    });
  }
}
