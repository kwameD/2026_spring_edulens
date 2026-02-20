
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';

class LeaderboardTable extends StatefulWidget {
  @override
  _LeaderboardTableState createState() => _LeaderboardTableState();
}


class _LeaderboardTableState extends State<LeaderboardTable> {
  List<Map<String, dynamic>>? _parsedScores;
  
  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      String jsonString = await rootBundle.loadString('assets/GameLeaderboard.txt');
      List<dynamic> jsonList = jsonDecode(jsonString);

      if (mounted) {
        setState(() {
          _parsedScores = jsonList.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print("Error while parsing: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Leaderboards', 
        userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 120,
          ),
          Container(
          margin: const EdgeInsets.all(10),
          child: Table(
            border: TableBorder.all(color: Colors.black, width: 1.0),
            children: [
              // Header Row
              TableRow(children: [
                TableCell(child: Center(child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold),),)),
                TableCell(child: Center(child: Text('Game', style: TextStyle(fontWeight: FontWeight.bold),))),
                TableCell(child: Center(child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold)),)),
              ]),
              // Data Rows
              if (_parsedScores != null && _parsedScores!.isNotEmpty) 

              ..._parsedScores!.asMap().entries.map((entry) {
                var value = entry.value;

                return TableRow(
                  children: [
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(value['student_name'].toString())),
                    ),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(value['game_name'].toString())),
                    ),
                    TableCell(child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(value['score'].toString())),
                    ),
                  ]
                );
              })
            ],
          )
        )]
      )
    );
  }
}