import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';
import '../widgets/burst_group_card.dart';
import 'manual_select_screen.dart';

class BurstListScreen extends StatefulWidget {
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
  State<BurstListScreen> createState() => _BurstListScreenState();
}

class _BurstListScreenState extends State<BurstListScreen> {
  late List<BurstGroup> _remaining;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _remaining = List.from(widget.groups);
  }

  Future<void> _openGroup(BurstGroup group) async {
    final done = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => ManualSelectScreen(
          group: group,
          service: widget.service,
          permanentlyDelete: widget.permanentlyDelete,
        ),
      ),
    );

    if (done == true && mounted) {
      setState(() {
        _remaining.remove(group);
        _completedCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('グループ一覧 (${_remaining.length}件)'),
      ),
      child: SafeArea(
        child: _remaining.isEmpty ? _buildCompleted() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        if (_completedCount > 0)
          SliverToBoxAdapter(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              child: Text(
                '$_completedCount グループ処理済み',
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGreen,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = _remaining[index];
              return BurstGroupCard(
                group: group,
                onTap: () => _openGroup(group),
              );
            },
            childCount: _remaining.length,
          ),
        ),
      ],
    );
  }

  Widget _buildCompleted() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 72,
            color: CupertinoColors.systemGreen,
          ),
          const SizedBox(height: 20),
          const Text(
            'すべて完了！',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$_completedCount グループを整理しました',
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            onPressed: () => Navigator.pop(context),
            child: const Text('ホームへ戻る'),
          ),
        ],
      ),
    );
  }
}
