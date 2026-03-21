import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:learninglens_app/Api/database/ai_logging_singleton.dart';
import 'package:learninglens_app/Api/lms/enum/lms_enum.dart';
import 'package:learninglens_app/Views/assessments_view.dart';
import 'package:learninglens_app/Views/program_assessment_view.dart';
import 'package:learninglens_app/Views/user_settings.dart';
import 'package:learninglens_app/Views/leaderboard_view.dart';
import 'package:learninglens_app/firebase_options.dart';
import 'package:learninglens_app/notifiers/login_notifier.dart';
import 'package:learninglens_app/notifiers/theme_notifier.dart';
import 'package:learninglens_app/services/gamification_service.dart';
import 'package:learninglens_app/services/local_storage_service.dart';
import 'package:learninglens_app/services/program_assessment_service.dart';
import 'package:learninglens_app/services/reflection_service.dart';
import 'package:provider/provider.dart';

import 'Views/dashboard.dart';
import 'Views/edit_questions.dart';
import 'Views/essay_generation.dart';
import 'Views/gamification_view.dart';
import 'Views/quiz_generator.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Added: ensure Flutter bindings are available before any async startup work runs.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // runApp(MyApp());
  await LocalStorageService.init(); // Initialize SharedPreferences
  await AILoggingSingleton().createDb();
  await AILoggingSingleton().clearOldDatabaseEntries();
  await ProgramAssessmentService.createDb();
  await GamificationService.createDb();
  await ReflectionService.createDb();

  // Added: initialize Firebase only once during startup.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await DatabaseSeeder.seedIfEmpty();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ThemeNotifier()), // Theme provider
        ChangeNotifierProvider(
            create: (_) => LoginNotifier()), // Login provider
      ],
      child: MyApp(),
    ),
  );
}

//click and drag for intuitiveness
class CustomScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

//below is an app builder, leave it here for now
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<LoginNotifier>(context);

    // used to determine which dashboard to show based on the local storage system
    var selectedClassroom = LocalStorageService.getSelectedClassroom();
    var home = selectedClassroom == LmsType.MOODLE
        ? TeacherDashboard()
        : TeacherDashboard(); //GoogleTeacherDashboard();

    // Added: read the selected theme settings once so both light and dark themes stay in sync.
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Learning Lens",
      home: home,
      navigatorKey: navigatorKey,
      // Added: apply the persisted light or dark mode setting.
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        // Added: keep Material 3 enabled while rebuilding the whole app from the chosen accent color.
        useMaterial3: true,
        // Added: generate the full light color scheme from the persisted theme picker color.
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeNotifier.primaryColor,
          brightness: Brightness.light,
          secondary: themeNotifier.secondaryColor,
        ),
        // Added: give the web and desktop app a clean neutral light background for stronger text contrast.
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        // Added: improve readability on light cards, inputs, and data tables.
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        // Added: make input labels and helper text easier to read against light surfaces.
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        // Added: improve table readability across analytics, IEP, and program-assessment pages.
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          dataTextStyle: TextStyle(color: Colors.black87),
        ),
      ),
      // Added: provide a richer dark theme with stronger text contrast and readable surfaces.
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeNotifier.primaryColor,
          brightness: Brightness.dark,
          secondary: themeNotifier.secondaryColor,
          surface: const Color(0xFF11131A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161B26),
          border: const OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.90)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white.withOpacity(0.94),
              displayColor: Colors.white.withOpacity(0.96),
            ),
        // Added: keep table headers and rows readable on dark surfaces.
        dataTableTheme: DataTableThemeData(
          headingRowColor: MaterialStatePropertyAll(Colors.white.withOpacity(0.08)),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.94),
          ),
          dataTextStyle: TextStyle(color: Colors.white.withOpacity(0.90)),
        ),
      ),
      scrollBehavior: CustomScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate, // <-- required for Quill
      ],
      supportedLocales: const [
        Locale('en'), // add more if you support multiple languages
      ],
      routes: {
        // '/EssayEditPage': (context) => EssayEditPage(jsonData),
        // '/Content': (context) => ViewCourseContents(),
        '/EssayGenerationPage': (context) =>
            EssayGeneration(title: 'Essay Generation'),
        '/QuizGenerationPage': (context) => CreateAssessment(),
        '/EditQuestions': (context) => EditQuestions(''),
        // '/create': (context) => const CreatePage(),
        '/dashboard': (context) => TeacherDashboard(),
        '/user': (context) => UserSettings(),
        //'/send_essay_to_moodle': (context) => EssayAssignmentSettings(''),
        '/assessments': (context) => AssessmentsView(),
        // '/viewExams': (context) => const View Exam Page(),
        // '/settings': (context) => Setting(themeModeNotifier: _themeModeNotifier)
        '/gamification': (context) => GamificationView(viewGames: false,),
        '/evaluate': (context) => ProgramAssessmentView()
      },
    );
  }
}

class DevLaunch extends StatefulWidget {
  @override
  State createState() {
    return _DevLaunch();
  }
}

class _DevLaunch extends State {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Dev Launch Page')),
        body: Column(children: [
          ElevatedButton(
              child: const Text('dashboard'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TeacherDashboard()),
                );
              }),
          // ElevatedButton(
          //     child: const Text('Open Edit Essay'),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(builder: (context) => EssayEditPage(jsonData)),
          //       );
          //     }),
          // ElevatedButton(
          //     child: const Text('Open Contents Carousel'),
          //     onPressed: () async {
          //       if (MoodleApiSingleton().isLoggedIn()){
          //         MainController().selectCourse(0);
          //       }
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //             builder: (context) => ViewCourseContents()),
          //       );
          //     }),
          ElevatedButton(
              child: const Text('Open Essay Generation'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          EssayGeneration(title: 'Essay Generation')),
                );
              }),
          ElevatedButton(
              child: const Text('Teacher Dashboard'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TeacherDashboard()),
                );
              }),
          // ElevatedButton(
          //     child: const Text('Send essay to Moodle'),
          //     onPressed: () {
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //             builder: (context) => EssayAssignmentSettings(tempRubricXML)),
          //       );
          //     }),
          ElevatedButton(
            child: const Text('Quiz Generator'),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => CreateAssessment()));
            },
          ),
          ElevatedButton(
            child: const Text('Edit Questions'),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => EditQuestions('')));
            },
          ),
          ElevatedButton(
              child: const Text('View Quizzes'),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => AssessmentsView()));
              }),
          ElevatedButton(
            child: const Text('Gamification Page'),
            onPressed: () {
              Navigator.pushNamed(context, '/gamification');
            },
          ),
        ]));
  }
}
