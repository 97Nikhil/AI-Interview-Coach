import 'package:AIC/repository/screens/splash/splashScreen.dart';
import 'package:flutter/material.dart';
import 'dart:async';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

// Add QuickStatsManager class here
class QuickStatsManager {
  static final QuickStatsManager _instance = QuickStatsManager._internal();
  factory QuickStatsManager() => _instance;
  QuickStatsManager._internal();

  final StreamController<Map<String, int>> _statsController =
  StreamController<Map<String, int>>.broadcast();

  Stream<Map<String, int>> get statsStream => _statsController.stream;

  void updateStats(int interviews, int resumeScore) {
    _statsController.add({
      'interviews': interviews,
      'resumeScore': resumeScore
    });
  }

  void dispose() {
    _statsController.close();
  }
}

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIC',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: SplashScreen(),
    );
  }
}