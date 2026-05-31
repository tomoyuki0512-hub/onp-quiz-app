import 'package:flutter/cupertino.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicQuizApp());
}

class MusicQuizApp extends StatelessWidget {
  const MusicQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'おんぷクイズ',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
