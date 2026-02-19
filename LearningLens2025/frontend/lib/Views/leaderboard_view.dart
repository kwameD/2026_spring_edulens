
import 'package:flutter/material.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';

class LeaderboardTable extends StatefulWidget {
  @override
  _LeaderboardTableState createState() => _LeaderboardTableState();
}

class _LeaderboardTableState extends State<LeaderboardTable> {
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
        children: [Container(
          margin: const EdgeInsets.all(10),
          child: Table(
            border: TableBorder.all(color: Colors.black, width: 1.0),
            children: [
              // Header Row
              TableRow(children: [
                TableCell(child: Center(child: Text('Student Name'),)),
                TableCell(child: Center(child: Text('Game'),)),
                TableCell(child: Center(child: Text('Score'),)),
              ])
            ],
          )
        )]
      )
    );
  }
}