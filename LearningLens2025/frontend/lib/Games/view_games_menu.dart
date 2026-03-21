import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Api/lms/lms_interface.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';
import 'package:learninglens_app/Games/airss_simulation.dart';
import 'package:learninglens_app/Games/timed_quiz_game.dart';
import 'package:learninglens_app/Views/nav_card.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

class ViewGamesList extends StatefulWidget {
  @override
  _GameListState createState() => _GameListState();
}

class _GameListState extends State<ViewGamesList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar(
          title: 'List of Generated Games',
          userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return _buildDesktopLayout(context, constraints);
              } else {
                return _buildMobileLayout(context, constraints);
              }
            }))
          ],
        ));
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final double screenWidth = constraints.maxWidth;

    double baseButtonSize = screenWidth * 0.15;
    double baseButtonFontSize = screenWidth * 0.015;
    double baseDescriptionFontSize = screenWidth * 0.015;

    double middleButtonSize = baseButtonSize * 1.2;
    double middleButtonFontSize = baseButtonFontSize * 1.2;
    double middleDescriptionFontSize = baseDescriptionFontSize * 1.1;

    baseButtonSize = baseButtonSize.clamp(80.0, 150.0);
    baseButtonFontSize = baseButtonFontSize.clamp(12.0, 18.0);
    baseDescriptionFontSize = baseDescriptionFontSize.clamp(12.0, 18.0);

    middleButtonSize = middleButtonSize.clamp(96.0, 180.0);
    middleButtonFontSize = middleButtonFontSize.clamp(14.0, 20.0);
    middleDescriptionFontSize = middleDescriptionFontSize.clamp(13.0, 20.0);

    double titleFontSize = screenWidth * 0.03;
    titleFontSize = titleFontSize.clamp(20.0, 32.0);

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGridLayout(context, constraints),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, BoxConstraints constraints) {
    final double screenWidth = constraints.maxWidth;

    double baseButtonSize = screenWidth * 0.35; // Reduced from 0.4
    double baseButtonFontSize = screenWidth * 0.04; // Reduced from 0.045
    double baseDescriptionFontSize = screenWidth * 0.035; // Reduced from 0.04

    double middleButtonSize = baseButtonSize * 1.1;
    double middleButtonFontSize = baseButtonFontSize * 1.1;
    double middleDescriptionFontSize = baseDescriptionFontSize * 1.05;

    baseButtonSize = baseButtonSize.clamp(70.0, 120.0); // Reduced max size
    baseButtonFontSize =
        baseButtonFontSize.clamp(10.0, 14.0); // Reduced max size
    baseDescriptionFontSize =
        baseDescriptionFontSize.clamp(10.0, 14.0); // Reduced max size

    middleButtonSize = middleButtonSize.clamp(77.0, 132.0);
    middleButtonFontSize = middleButtonFontSize.clamp(11.0, 16.0);
    middleDescriptionFontSize = middleDescriptionFontSize.clamp(11.0, 15.0);

    double titleFontSize = screenWidth * 0.06;
    titleFontSize = titleFontSize.clamp(16.0, 22.0); // Reduced max size

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced from 16.0
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGridLayout(context, constraints),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context, BoxConstraints constraints) {
    final role = LocalStorageService.getUserRole();
    final userId = LocalStorageService.getUserId();

    // Helper function to determine which game to show to the user
    bool isGameVisible(List<int> assignedStudents) {
      // If the user is a teacher, show all games
      if (role == UserRole.teacher) {
        return true;
      } else {
        // Check the assignedStudents field of the game, show to current user if assigned
        if (assignedStudents.any((student) => student.toString() == userId)) {
          return true;
        } else if (assignedStudents.isEmpty) {
          // Else if assigned students is empty, show to all users
          return true;
        }
      }
      return false;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Games').snapshots(),
      builder: (context, snapshot) {
        // Retrieve the games from storage and display to UI
        if (snapshot.hasError) {
          return Text('Error loading games: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        // Parse the retrieved games into a List, create NavigationCards from list
        List<Map<String, dynamic>> gameButtonData =
            snapshot.data!.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          final gameType = data['gameType']?.toString() ?? 'Quiz Game';
          return {
            'title': data['title'],
            'questions': data['questions'],
            'gameType': gameType,
            'description': data['description'] ?? 'No description provided.',
            'basePointsPerSec': data['basePointsPerSec'] ?? 5,
            'difficulty': data['difficulty'] ?? 'N/A',
            'roundTime': data['roundTime'] ?? 20,
            'transitionTime': data['transitionTime'] ?? 3,
            'icon': gameType == 'AIRSS Simulation'
                ? Icons.record_voice_over_outlined
                : Icons.gamepad_outlined,
            'visible': isGameVisible(List.from(data['assignedStudents'] ?? [])),
          };
        }).toList();

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: gameButtonData
                .where((data) => data['visible'] == true)
                .map((data) => SizedBox(
                    width: 550,
                    height: 440,
                    child: NavigationCard(
                        title: data['title'],
                        description: data['description'],
                        icon: data['icon'],
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                if (data['gameType'] == 'AIRSS Simulation') {
                                  return Scaffold(
                                    appBar: AppBar(title: Text(data['title'])),
                                    body: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: AirssSimulationGame(
                                        scenarios:
                                            List<Map<String, dynamic>>.from(
                                          data['questions'] ?? const [],
                                        ),
                                        title: data['title'],
                                        description: data['description'],
                                        llmType: 'ChatGPT',
                                        previewMode: false,
                                        onComplete: (_) {},
                                      ),
                                    ),
                                  );
                                }
                                return TimedQuizGame(
                                  basePointsPerSec: data['basePointsPerSec'],
                                  difficulty: data['difficulty'],
                                  gameTitle: data['title'],
                                  gameDescription: data['description'],
                                  questions: List<Map<String, dynamic>>.from(
                                      data['questions'] ?? const []),
                                  roundTime: data['roundTime'],
                                  transitionTime: data['transitionTime'],
                                );
                              },
                            )))))
                .toList(),
          ),
        );
      },
    );
  }
}
