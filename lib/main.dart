import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const WrongAnswerApp());
}

class WrongAnswerApp extends StatelessWidget {
  const WrongAnswerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오답 모음집',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90D9),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'pretendard',
      ),
      home: const HomeScreen(),
    );
  }
}
