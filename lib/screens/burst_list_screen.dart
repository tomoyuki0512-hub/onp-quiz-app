import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';

class BurstListScreen extends StatelessWidget {
  final List<BurstGroup> groups;
  final BurstPhotoService service;
  final bool permanentlyDelete;

  const BurstListScreen({
    super.key,
    required this.groups,
    required this.service,
    required this.permanentlyDelete,
  });

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('グループ一覧'),
      ),
      child: Center(
        child: Text('未実装'),
      ),
    );
  }
}
