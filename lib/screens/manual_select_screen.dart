import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';

class ManualSelectScreen extends StatelessWidget {
  final BurstGroup group;
  final BurstPhotoService service;
  final bool permanentlyDelete;

  const ManualSelectScreen({
    super.key,
    required this.group,
    required this.service,
    required this.permanentlyDelete,
  });

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('写真選択'),
      ),
      child: Center(
        child: Text('未実装'),
      ),
    );
  }
}
