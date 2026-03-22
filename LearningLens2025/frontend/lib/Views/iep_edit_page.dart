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
import 'package:learninglens_app/Views/iep_page.dart';
import 'package:learninglens_app/beans/course.dart';
import 'package:learninglens_app/beans/override.dart';
import 'package:learninglens_app/beans/participant.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

final db = FirebaseFirestore.instance;
final iep = db.collection('IEP');

class IepEditPage extends StatefulWidget {
  final String documentId;
  const IepEditPage({super.key, required this.documentId});

  @override
  State<IepEditPage> createState() => _IepEditPageState();
}

class _IepEditPageState extends State<IepEditPage> {
  final db = FirebaseFirestore.instance;

  List<String> gradeLevels = [
    "N/A",
    "Kindergarten",
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

  bool _isLoading = true;

  String? errorMessage;
  String? studentName;
  String? selectedCourseName;
  String? fullname;
  int? userId;
  int? courseId;
  String? selectedGradeLevel;
  String? selectedDisability;

  TextEditingController _dueDateController = TextEditingController();
  TextEditingController studentKnowledgeController = TextEditingController();
  TextEditingController disabilityController = TextEditingController();
  TextEditingController courseController = TextEditingController();
  TextEditingController gradeLevelController = TextEditingController();
  TextEditingController iepRecommendationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadIepData();
  }

  Future<void> loadIepData() async {
    try {
      final doc = await db.collection("IEP").doc(widget.documentId).get();

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          selectedGradeLevel = data["gradeLevel"];
          selectedDisability = data["disability"];
          studentName = data["fullName"];
          courseId = data["courseId"];
          userId = data["userId"];
          fullname = data["fullName"];
          selectedCourseName = data["courseName"];

          courseController.text = data["courseName"] ?? "";
          gradeLevelController.text = selectedGradeLevel ?? "";
          disabilityController.text = selectedDisability ?? "";
          studentKnowledgeController.text = data["studentKnowledge"] ?? "";
          iepRecommendationController.text = data["iep"] ?? "";
          _dueDateController.text = data["dueDate"] ?? "";

          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading IEP: $e")),
      );
    }
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
      initialDate: DateTime.tryParse(_dueDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text =
            "${picked.year}-${picked.month}-${picked.day}";
      });
    }
  }

  Future<void> editIEP() async {
    try {
      final iepData = {
        "courseId": courseId,
        "userId": userId,
        "fullName": fullname,
        "gradeLevel": selectedGradeLevel,
        "disability": selectedDisability,
        "courseName": selectedCourseName,
        "studentKnowledge": studentKnowledgeController.text,
        "iep": iepRecommendationController.text,
        "dueDate": _dueDateController.text,
      };

      await db.collection("IEP").doc(widget.documentId).update(iepData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("IEP updated successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating IEP: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Edit IEP - $fullname")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: courseController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Course"),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedGradeLevel,
              decoration: const InputDecoration(
                labelText: "Grade Level",
                border: OutlineInputBorder(),
              ),
              items: gradeLevels.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGradeLevel = value;
                  gradeLevelController.text = value ?? "";
                });
              },
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedDisability,
              decoration: const InputDecoration(
                labelText: "Disability",
                border: OutlineInputBorder(),
              ),
              items: disabilityCategories.map((disability) {
                return DropdownMenuItem(
                  value: disability,
                  child: Text(disability),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDisability = value;
                  disabilityController.text = value ?? "";
                });
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _selectDate,
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
            ),
            SizedBox(height: 10),
            TextField(
              controller: studentKnowledgeController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: "Student Knowledge"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: iepRecommendationController,
              maxLines: 8,
              decoration: const InputDecoration(labelText: "IEP Content"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, // Set the text color to black
                  backgroundColor: Colors
                      .green, // Set the button's background color (optional)
                ),
                onPressed: () async {
                  // check to see if all fields are filled out
                  if (_dueDateController.text.isNotEmpty &&
                      studentKnowledgeController.text.isNotEmpty &&
                      disabilityController.text.isNotEmpty &&
                      courseController.text.isNotEmpty &&
                      gradeLevelController.text.isNotEmpty &&
                      iepRecommendationController.text.isNotEmpty) {
                    await editIEP();
                    setState(() {
                      errorMessage = "";
                    });
                  } else {
                    setState(() {
                      errorMessage = "All fields must be filled out.";
                    });
                  }
                },
                child: const Text("Update IEP"),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                errorMessage ?? "",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
