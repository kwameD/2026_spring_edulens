
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';

class LeaderboardTable extends StatefulWidget {
  @override
  _LeaderboardTableState createState() => _LeaderboardTableState();
}

// Checks the Firestore DB for leaderboard scores, if empty, seed local data
// If the data exists, do nothing. Data is pulled to populate table in _loadLeaderboard
class DatabaseSeeder {
  static Future<void> seedIfEmpty() async {
    final collection = FirebaseFirestore.instance.collection('leaderboard');
    
    // Check if any documents exist
    final snapshot = await collection.limit(1).get();

    if (snapshot.docs.isEmpty) {
      print("Leaderboard is empty. Seeding from local asset...");
      
      // Load and decode your local JSON file
      final String jsonString = await rootBundle.loadString('assets/GameLeaderboard.txt');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      // Use a batch for efficient multi-document upload
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var entry in jsonList) {
        // Create a unique ID to prevent duplicates if seed runs twice
        String customId = "${entry['student_name']}_${entry['game_name']}".toLowerCase();
        var docRef = collection.doc(customId);
        
        batch.set(docRef, {
          'student_name': entry['student_name'],
          'game_name': entry['game_name'],
          'score': entry['score'],
          'initialized_at': FieldValue.serverTimestamp(),
        });
      }

      try {
        await batch.commit();
        print("Seeding complete!");
      } catch (e) {
        print("Error writing to Firestore DB: $e");
      }
    } else {
      print("Loaded leaderboard data from Firestore.");
    }
  }
}

class _LeaderboardTableState extends State<LeaderboardTable> {
  // Builds the UI for the leaderboard table
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Leaderboards', 
        userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [StreamBuilder<QuerySnapshot>(
            // Pull data from Firestore DB leaderboard collection to populate table
            stream: FirebaseFirestore.instance
              .collection('leaderboard')
              .orderBy('score', descending: true)
              .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error loading leaderboard: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }

              List<DataRow> rows = snapshot.data!.docs.map((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(data['student_name'] ?? 'N/A')),
                  DataCell(Text(data['game_name'] ?? 'N/A')),
                  DataCell(Text(data['score'].toString())),
                ]);
              }).toList();

              // Return the table with the gathered data, sorted by descending score
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Icon(
                      Icons.leaderboard_outlined,
                      size: 120,
                    ),
                    Container(
                      margin: const EdgeInsets.all(10),
                      child: DataTable(
                        border: TableBorder.all(color: Colors.black, width: 1.0),
                        columns: const [
                          DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold),)),
                          DataColumn(label: Text('Game Name', style: TextStyle(fontWeight: FontWeight.bold),)),
                          DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold),)),
                        ],
                        rows: rows,
                      )
                    )
                  ]
                ),
              );
            },
          )]
       )
      )
    );
  }
}