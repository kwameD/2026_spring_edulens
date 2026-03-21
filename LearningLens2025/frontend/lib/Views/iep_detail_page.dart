import 'package:cloud_firestore/cloud_firestore.dart';
import "package:flutter/material.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:learninglens_app/Api/lms/factory/lms_factory.dart";
import "package:learninglens_app/Controller/custom_appbar.dart";

final db = FirebaseFirestore.instance;
final iep = db.collection('IEP');

class IepDetailPage extends StatefulWidget {
  final String documentId;

  const IepDetailPage({super.key, required this.documentId});

  @override
  _IepDetailState createState() => _IepDetailState();
}

class _IepDetailState extends State<IepDetailPage> {
  @override
  void initState() {
    super.initState();
  }

  Future<DocumentSnapshot?> getIepById(String id) async {
    print("doc id $id");
    final doc = await iep.doc(id).get();
    return doc.exists ? doc : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Individual Education Plans Detail',
        userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
      ),
      body: FutureBuilder(
        future: getIepById(widget.documentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("No data found"));
          }

          final data = snapshot.data!;

          final name = data['fullName'] ?? "N/A";
          final dueDate = data['dueDate'] ?? "N/A";
          final disability = data['disability'] ?? "N/A";
          final gradeLevel = data['gradeLevel'] ?? "N/A";
          final iep = data['iep'] ?? "";
          final courseName = data['courseName'] ?? "";
          final studentKnowledge = data['studentKnowledge'] ?? "";

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Student's Name",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                name,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Grade Level",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                gradeLevel,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Disability",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                disability,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Course Name",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                courseName,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Due Date",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                dueDate,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Student Knowledge",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(studentKnowledge),
                  SizedBox(height: 20),
                  Text(
                    "IEP",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Divider(color: Colors.black),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Markdown(
                      data: iep,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
