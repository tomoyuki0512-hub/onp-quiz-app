import 'package:flutter/cupertino.dart';
import '../services/burst_photo_service.dart';

class HomeScreen extends StatelessWidget {
  final BurstPhotoService service;

  const HomeScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('バースト写真クリーナー'),
      ),
      child: Center(
        child: Text('未実装'),
      ),
    );
  }
}
