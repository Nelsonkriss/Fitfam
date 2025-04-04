import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'resource/db_provider.dart';
import 'resource/firebase_provider.dart';
import 'package:workout_planner/ui/setting_page.dart';
import 'package:workout_planner/ui/statistics_page.dart';
import 'bloc/routines_bloc.dart';
import 'resource/shared_prefs_provider.dart';

import 'ui/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase for all platforms
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize DB provider
    await dbProvider.initDB();
    
    // Start app
    runApp(App());
    
    // Fetch routines
    routinesBloc.fetchAllRoutines();
    routinesBloc.fetchAllRecRoutines();
    
  } catch (e) {
    // Show error screen if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 50, color: Colors.red),
              SizedBox(height: 20),
              Text('Initialization Error', style: TextStyle(fontSize: 24)),
              SizedBox(height: 10),
              Text('Failed to start app: $e', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ));
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.blueGrey[800],
        primarySwatch: Colors.grey,
        fontFamily: 'Staa',
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      debugShowCheckedModeBanner: false,
      title: 'Dumbbell',
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          return MainPage();
        },
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final pageController = PageController(initialPage: 0, keepPage: true);
  final scrollController = ScrollController();
  final scaffoldKey = GlobalKey<ScaffoldState>();

  var tabs = [HomePage(), StatisticsPage(), SettingPage()];
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    // Always fetch routines, WebDBProvider handles web storage
    routinesBloc.fetchAllRoutines();
    routinesBloc.fetchAllRecRoutines();

    firebaseProvider.signInSilently().then((_) {
      if (kDebugMode) {
        print("Sign in silently end");
      }
    });

    sharedPrefsProvider.prepareData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Dumbbell'),
          toolbarHeight: 72,
          centerTitle: false,
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.wrap_text)),
              Tab(icon: Icon(Icons.history)),
              Tab(icon: Icon(Icons.settings)),
            ],
          ),
        ),
        body: TabBarView(children: tabs),
      ),
    );
  }
}
