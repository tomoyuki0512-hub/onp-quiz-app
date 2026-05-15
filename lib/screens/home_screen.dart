import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';
import 'burst_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final BurstPhotoService service;

  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _permissionStatus = 'notDetermined';
  List<BurstGroup>? _groups;
  bool _isLoading = false;
  int _minCount = 2;
  bool _permanentlyDelete = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    final status = await widget.service.requestPermission();
    setState(() => _permissionStatus = status);

    if (status == 'authorized' || status == 'limited') {
      await _loadGroups();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await widget.service.getBurstGroups();
      setState(() => _groups = groups);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<BurstGroup> get _filteredGroups {
    if (_groups == null) return [];
    return _groups!.where((g) => g.count >= _minCount).toList();
  }

  int get _totalDeletable {
    return _filteredGroups.fold(0, (sum, g) => sum + g.count - 1);
  }

  void _showPermanentDeleteHelp() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('削除モードの違い'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Text(
              'OFF（最近削除した項目へ移動）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              '写真を「最近削除した項目」に移動します。30日間は復元可能です。',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              'ON（即座に完全削除）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.destructiveRed,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '⚠️ 「最近削除した項目」を経由せず即座に完全削除します。元に戻せません。',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _emptyRecentlyDeleted() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('最近削除した項目を空にする'),
        content: const Column(
          children: [
            SizedBox(height: 8),
            Text(
              '「最近削除した項目」内の写真・動画をすべて完全削除します。',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              '⚠️ この操作は元に戻せません。',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.destructiveRed,
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
            child: const Text('完全削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final count = await widget.service.emptyRecentlyDeleted();
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('完了'),
          content: Text(
            count > 0
                ? '$count枚を完全削除しました。'
                : '最近削除した項目に写真はありませんでした。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('エラー'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAutoClean() async {
    final groups = _filteredGroups;
    if (groups.isEmpty) return;

    final totalDelete = _totalDeletable;
    final totalKeep = groups.length;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('おまかせクリーン'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              _permanentlyDelete
                  ? '$totalKeep枚を残し、$totalDelete枚を完全削除します。'
                  : '$totalKeep枚を残し、$totalDelete枚を最近削除した項目に移動します。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _permanentlyDelete
                  ? '⚠️ 完全削除します。元に戻せません。'
                  : '30日後に自動削除されます。',
              style: TextStyle(
                fontSize: 13,
                color: _permanentlyDelete
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'iOSの確認ダイアログが表示されます。「削除」をタップして許可してください。',
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
            isDestructiveAction: _permanentlyDelete,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_permanentlyDelete ? '完全削除する' : '移動する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    // 全グループの ID をまとめて1回の API 呼び出しに集約
    final allIdsToDelete = <String>[];
    for (final group in groups) {
      allIdsToDelete.addAll(
        group.assetIds.where((id) => id != group.autoPickId),
      );
    }

    int deletedCount = 0;
    String? errorMessage;

    try {
      if (allIdsToDelete.isNotEmpty) {
        final ok = _permanentlyDelete
            ? await widget.service.permanentlyDeleteAssets(allIdsToDelete)
            : await widget.service.deleteAssets(allIdsToDelete);
        if (ok) deletedCount = allIdsToDelete.length;
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    await _loadGroups();

    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(errorMessage == null ? '完了！' : '削除エラー'),
        content: Text(
          errorMessage == null
              ? _permanentlyDelete
                  ? '$totalKeep枚を残して$deletedCount枚を完全削除しました。'
                  : '$totalKeep枚を残して$deletedCount枚を最近削除した項目に移動しました。'
              : 'エラーが発生しました:\n$errorMessage',
        ),
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('バースト写真クリーナー'),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionStatus == 'denied' || _permissionStatus == 'restricted') {
      return _buildPermissionDenied();
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 16),
            Text(
              'フォトライブラリを確認中...',
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildFilterSection(),
        const SizedBox(height: 20),
        _buildStatsSection(),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'バースト枚数フィルター',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 36,
                onPressed:
                    _minCount > 2 ? () => setState(() => _minCount--) : null,
                child: const Icon(
                  CupertinoIcons.minus_circle_fill,
                  size: 30,
                  color: CupertinoColors.systemBlue,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: Text(
                  _minCount == 2 ? 'すべて\n(2枚以上)' : '$_minCount 枚以上',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 36,
                onPressed:
                    _minCount < 99 ? () => setState(() => _minCount++) : null,
                child: const Icon(
                  CupertinoIcons.plus_circle_fill,
                  size: 30,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Text(
                      '実際に削除する',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showPermanentDeleteHelp,
                      child: const Icon(
                        CupertinoIcons.question_circle,
                        size: 17,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _permanentlyDelete,
                activeColor: CupertinoColors.destructiveRed,
                onChanged: (v) => setState(() => _permanentlyDelete = v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _permanentlyDelete
                ? '⚠️ 最近削除した項目を経由せず即座に完全削除（元に戻せません）'
                : '削除した写真は最近削除した項目に移動されます（30日間復元可能）',
            style: TextStyle(
              fontSize: 12,
              color: _permanentlyDelete
                  ? CupertinoColors.destructiveRed
                  : CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final groups = _filteredGroups;
    if (groups.isEmpty && _groups != null) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${groups.length}', 'グループ'),
          Container(width: 1, height: 36, color: CupertinoColors.separator),
          _statItem('$_totalDeletable', '削除可能枚数'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.systemBlue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(
          CupertinoIcons.photo_on_rectangle,
          size: 64,
          color: CupertinoColors.systemGrey3,
        ),
        const SizedBox(height: 16),
        const Text(
          'バースト写真が見つかりませんでした',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'フィルターを変えるか、条件を変更して\n再スキャンしてみてください。',
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        CupertinoButton(
          onPressed: _loadGroups,
          child: const Text('再スキャン'),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final groups = _filteredGroups;
    final hasGroups = groups.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoButton.filled(
          onPressed: hasGroups ? _runAutoClean : null,
          borderRadius: BorderRadius.circular(12),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.wand_stars, size: 20),
              SizedBox(width: 8),
              Text(
                'おまかせクリーン',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'iOSが選んだベストショットを1枚残して自動削除します',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        CupertinoButton(
          onPressed: hasGroups
              ? () async {
                  await Navigator.push<void>(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => BurstListScreen(
                        groups: groups,
                        service: widget.service,
                        permanentlyDelete: _permanentlyDelete,
                      ),
                    ),
                  );
                  _loadGroups();
                }
              : null,
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.hand_draw,
                size: 20,
                color: hasGroups
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey3,
              ),
              const SizedBox(width: 8),
              Text(
                '自分で選ぶ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: hasGroups
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'グループごとに残したい1枚を自分で選択します',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          height: 0.5,
          color: CupertinoColors.separator.resolveFrom(context),
        ),
        const SizedBox(height: 20),
        CupertinoButton(
          onPressed: _emptyRecentlyDeleted,
          color: CupertinoColors.systemRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.trash, size: 18, color: CupertinoColors.destructiveRed),
              SizedBox(width: 8),
              Text(
                '最近削除した項目を空にする',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '「最近削除した項目」内の写真・動画をすべて完全削除します',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.lock_shield,
              size: 64,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 20),
            const Text(
              'フォトライブラリへのアクセスが必要です',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '設定アプリでこのアプリのフォトライブラリアクセスを許可してください。',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            CupertinoButton.filled(
              onPressed: () async {
                await _initialize();
              },
              child: const Text('再確認する'),
            ),
          ],
        ),
      ),
    );
  }
}
