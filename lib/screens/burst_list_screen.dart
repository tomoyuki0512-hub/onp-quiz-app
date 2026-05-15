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
  bool _isSelectMode = false;
  final Set<String> _selectedBurstIds = {};
  bool _isDeleting = false;

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

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) _selectedBurstIds.clear();
    });
  }

  void _toggleSelection(BurstGroup group) {
    setState(() {
      if (_selectedBurstIds.contains(group.burstId)) {
        _selectedBurstIds.remove(group.burstId);
      } else {
        _selectedBurstIds.add(group.burstId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final selected =
        _remaining.where((g) => _selectedBurstIds.contains(g.burstId)).toList();
    if (selected.isEmpty) return;

    final deleteCount = selected.fold<int>(0, (sum, g) => sum + g.count - 1);
    final permanently = widget.permanentlyDelete;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('選択グループを削除'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '${selected.length}グループのベストショット各1枚を残して、$deleteCount枚を${permanently ? "完全削除" : "削除"}します。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              permanently
                  ? '⚠️ 完全削除すると元に戻せません。'
                  : '削除した写真は「最近削除した項目」に30日間残ります。',
              style: TextStyle(
                fontSize: 13,
                color: permanently
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'iOSの確認ダイアログが表示されます。「削除」をタップしてください。',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(permanently ? '完全削除する' : '削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final idsToDelete = <String>[];
      for (final g in selected) {
        idsToDelete.addAll(g.assetIds.where((id) => id != g.autoPickId));
      }

      final success = permanently
          ? await widget.service.permanentlyDeleteAssets(idsToDelete)
          : await widget.service.deleteAssets(idsToDelete);

      if (!mounted) return;

      if (success) {
        setState(() {
          for (final g in selected) {
            _remaining.remove(g);
            _completedCount++;
          }
          _selectedBurstIds.clear();
          _isSelectMode = false;
        });
      } else {
        _showErrorDialog('削除に失敗しました。もう一度お試しください。');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('エラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          _isSelectMode
              ? '${_selectedBurstIds.length}件を選択中'
              : 'グループ一覧 (${_remaining.length}件)',
        ),
        trailing: _isDeleting
            ? const CupertinoActivityIndicator(radius: 10)
            : _remaining.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleSelectMode,
                    child: Text(
                      _isSelectMode ? 'キャンセル' : '選択',
                      style: const TextStyle(fontSize: 15),
                    ),
                  )
                : null,
      ),
      child: SafeArea(
        child: _remaining.isEmpty
            ? _buildCompleted()
            : Column(
                children: [
                  Expanded(child: _buildList()),
                  if (_isSelectMode) _buildSelectionBar(),
                ],
              ),
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
              final isSelected = _selectedBurstIds.contains(group.burstId);
              return BurstGroupCard(
                group: group,
                isSelectMode: _isSelectMode,
                isSelected: isSelected,
                onTap: _isSelectMode
                    ? () => _toggleSelection(group)
                    : () => _openGroup(group),
              );
            },
            childCount: _remaining.length,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final count = _selectedBurstIds.length;
    final allSelected = count == _remaining.length;
    final permanently = widget.permanentlyDelete;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 36,
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedBurstIds.clear();
                } else {
                  _selectedBurstIds.addAll(_remaining.map((g) => g.burstId));
                }
              });
            },
            child: Text(
              allSelected ? '全解除' : '全選択',
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: count > 0 && !_isDeleting ? _deleteSelected : null,
              borderRadius: BorderRadius.circular(12),
              child: Text(
                count > 0
                    ? '$count グループを${permanently ? "完全削除" : "削除"}'
                    : 'グループを選択してください',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
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
