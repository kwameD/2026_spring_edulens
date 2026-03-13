
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learninglens_app/Api/lms/factory/lms_factory.dart';
import 'package:learninglens_app/Controller/custom_appbar.dart';

class TimedQuizGame extends StatefulWidget {
  final String gameTitle;
  final List<Map<String, dynamic>> questions;
  final String difficulty;

  const TimedQuizGame ({
    super.key,
    required this.gameTitle,
    required this.questions,
    required this.difficulty,
  });
  
  @override
  _TimedGameState createState() => _TimedGameState();
}

// Enum for the flow of the game states
enum GameState {start, playing, results}

class _TimedGameState extends State<TimedQuizGame> {
  final int answerTime = 20; // The seconds the student has to answer
  final int transitionTime = 3; // The seconds between each question
  
  GameState _state = GameState.start;
  int _totalPointsEarned = 0;

  int currentQuestionIndex = 0;
  int _secondsRemaining = 20;
  int _pointsEarned = 0;
  Timer? _timer;

  String? _selectedOption;
  String? _correctAnswer;
  bool _isAnswered = false;

  /// Function to handle starting the timer based on the secondsRemaining value.
  /// This counts down each second, and at 0, moves on to the next question, or
  /// ends the game depending on the game's state.
  void _startTimer(int secondsRemaining) {
    _timer?.cancel();
    _secondsRemaining = secondsRemaining;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          // If timer runs out in transition phase, move to next question
          if (_isAnswered) {
            if (currentQuestionIndex < widget.questions.length - 1) {
              _isAnswered = false;
              _selectedOption = null;
              currentQuestionIndex++;
              _startTimer(answerTime);
            } else { // Else end game if at last question
               _state = GameState.results;
            }
          } else {
            _handleAnswer("!WRONG_ANSWER!");
          }
        }
      });
    });
  }

  // Stop the timer when the user leaves the quiz page
  @override
  void dispose() {
    _timer?.cancel(); // Stops the timer immediately
    super.dispose(); // Notifies the framework
  }

  // Handles validating the answer and adding the points to the total score
  void _handleAnswer(String selectedOption) {
    if(_isAnswered) return; // Ignore check if already answered
    
    _timer?.cancel(); // Stop the timer

    // Handle state changes
    setState(() {
      _isAnswered = true;
      _selectedOption = selectedOption;
      int pointsEarned = _secondsRemaining * 5;
      _pointsEarned = pointsEarned;
      _startTimer(transitionTime); // Start transition timer
      if (_correctAnswer == selectedOption) {
        _totalPointsEarned += pointsEarned;
      }
    });
  }
  
  /// Build the main body/scaffold for the page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Timed Quiz Game: ${widget.gameTitle}', 
        userprofileurl: LmsFactory.getLmsService().profileImage ?? '',
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: _buildBody(context),
      ),
    );
  }

  /// The swtich for building the body based on the progression of the game.
  /// The game goes: Start -> Playing -> Results
  Widget _buildBody(BuildContext context) {
    switch(_state) {
      case GameState.start:
        return _buildStartScreen(context);
      case GameState.playing:
        return _buildQuestionsScreen(context);
      case GameState.results:
        return _buildResultsScreen(context);
    }
  }

  /// Builds the starting screen for the game. This houses the name of the game,
  /// the number of questions, the difficulty, and the total possible points of the
  /// whole game. The start button is also here to start the game.
  Widget _buildStartScreen(BuildContext context) {
    int numOfQuestions = widget.questions.length;
    int totalPossPoints = numOfQuestions * 100; // 100 possible points per quesiton
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start the game: ${widget.gameTitle}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
          ),
          Text (
            'Number of Questions: $numOfQuestions'
          ),
          Text(
            'Difficulty Level: ${widget.difficulty}'
          ),
          Text(
            'Total Possible Points: $totalPossPoints'
          ),
          Center(
            child: ElevatedButton(
              child: const Text('Start Game'),
              onPressed: () {
                setState(() => _state = GameState.playing);
                _startTimer(answerTime);
              },
            )
          ),
        ],
      )
    );
  }

  /// This builds the screen that holds the questions. Here, the timer
  /// and number of questions is placed on the top. Next, the question is placed
  /// below the timer, after that the four possible answers are placed beneath that.
  /// When a user answers, a hidden prompt appears between the question and answers,
  /// telling the user the points they gained (if answered correctly), or what the
  /// correct answer was.
  Widget _buildQuestionsScreen(BuildContext context) {
    int totalQuestions = widget.questions.length;

    final currentQuestion = widget.questions[currentQuestionIndex];
    final List<String> options = List<String>.from(currentQuestion['options']);
    final correctAnswerIndex = currentQuestion['answer'];
    final correctAnswer = options[correctAnswerIndex];
    _correctAnswer = correctAnswer;

    // Helper function to color the correct option after answering
    Color? getButtonColor(String option, String correctAnswer) {
      // If not answered yet, add no color
      if (!_isAnswered) return null;

      // Color the correct answer green
      if (option == correctAnswer) {
        return Colors.green.withOpacity(0.5);
      }

      // Color the incorrect selection red
      if (option == _selectedOption) {
        return Colors.red.withOpacity(0.5);
      }

      // Return, leaving the wrong options un-colored
      return null;
    } 

    // Return the Question and Answers area
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header containing remaining time and question out of total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_isAnswered ? 'Next Question In' : 'Time'} : $_secondsRemaining s", style: TextStyle(fontSize: 18, color: Colors.red)),
              Text("Question: ${currentQuestionIndex + 1}/$totalQuestions", style: TextStyle(fontSize: 18)),
            ],
          ),
          SizedBox(height: 40),
          // Center containing the question
          Text(
            currentQuestion['question'],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          // The text that tells the user their gained points, or the correct answer
          // This is hidden until the user answers the question.
          SizedBox(height: 40),
          if (_selectedOption == correctAnswer) 
            Text(
              'Correct! You earned $_pointsEarned points!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.green,
              ),
            ),
          if (_selectedOption != null && _selectedOption != correctAnswer)
            Text(
              'Incorrect! The correct answer was: $_correctAnswer',
              style: TextStyle(
                fontSize: 20,
                color: Colors.red,
              ),
            ),
          SizedBox(height: 40),
          // The four options of answers
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final String optionText = options[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: getButtonColor(options[index], correctAnswer),
                      side: BorderSide(color: Colors.black12),
                    ),
                    onPressed: () => _handleAnswer(options[index]),
                    child: Text(optionText)
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // TODO: Build the resuts screen.
  // TODO: Add the game results to the firebase leaderboard
  /// This builds the results screen.
  Widget _buildResultsScreen(BuildContext context) {
    return SingleChildScrollView(
      child: Text("Total Points Earned: $_totalPointsEarned"),
    );
  }
}