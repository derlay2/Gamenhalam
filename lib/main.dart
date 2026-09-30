import 'package:flutter/material.dart';

import 'screens/save_slots_screen.dart';

void main() {
  runApp(const HunterGuildApp());
}

class HunterGuildApp extends StatelessWidget {
  const HunterGuildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hunter Guild',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      ),
      home: const SaveSlotsScreen(),
    );
  }
}
