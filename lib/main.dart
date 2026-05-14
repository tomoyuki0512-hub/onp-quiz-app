import 'package:flutter/cupertino.dart';
import 'screens/home_screen.dart';
import 'services/burst_photo_service.dart';

void main() {
  runApp(const PhotoDeleterApp());
}

class PhotoDeleterApp extends StatelessWidget {
  const PhotoDeleterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'バースト写真クリーナー',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: HomeScreen(service: BurstPhotoService()),
      debugShowCheckedModeBanner: false,
    );
  }
}
