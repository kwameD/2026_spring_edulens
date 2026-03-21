import 'package:flutter/material.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Api/lms/lms_interface.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';
import 'package:learninglens_app/Games/view_games_menu.dart';
import 'package:learninglens_app/Views/gamification_view.dart';
import 'package:learninglens_app/Views/leaderboard_view.dart';
import 'package:learninglens_app/Views/nav_card.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

class GamificationMenu extends StatefulWidget {
  @override
  _GameMenuState createState() => _GameMenuState();
}

class _GameMenuState extends State<GamificationMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Game Menu', 
        userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildDesktopLayout(context, constraints);
                } else {
                  return _buildMobileLayout(context, constraints);
                }
              },
            ),
          )
        ],
      )
    );
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
    
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1200),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          if (role == UserRole.teacher)
            SizedBox(
              width: 350,
              height: 140,
              child: NavigationCard(
                title: 'Create a game', 
                description: 'Create quiz, matching, flashcard, and AIRSS simulation activities.', 
                icon: Icons.videogame_asset_outlined, 
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GamificationView(viewGames: false,))
                ),
              )
            ),
          if (role == UserRole.teacher)
            SizedBox(
              width: 350,
              height: 140,
              child: NavigationCard(
                title: 'AIRSS Sessions',
                description: 'Launch the roleplay session builder for high-stakes stakeholder simulations.',
                icon: Icons.record_voice_over_outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GamificationView(viewGames: false,))
                ),
              )
            ),
          SizedBox(
            width: 350,
            height: 140,
            child: NavigationCard(
              title: 'Games', 
              description: 'View and play your current games.', 
              icon: Icons.library_books_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ViewGamesList())
              ),
            )
          ),
          SizedBox(
            width: 350,
            height: 140,
            child: NavigationCard(
              title: 'Leaderboards',
              description: 'View the current leaderboards.',
              icon: Icons.leaderboard_outlined,
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => LeaderboardTable())
              )
            ),
          )
        ],
      )
    );
  }
}
