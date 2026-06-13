import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'screens/games_hub_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize the global storage singleton before using it
  await initLocalStorage();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nebula Play - Games Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7B2CBF),
          secondary: Color(0xFF00F2FE),
          surface: Color(0xFF141622),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF141622),
          elevation: 8,
        ),
      ),
      home: const GamesHubScreen(),
    );
  }
}
