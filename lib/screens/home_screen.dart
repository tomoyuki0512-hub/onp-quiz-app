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
        title: const Text('実際に削除するとは？'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Text(
              'OFF（デフォルト・確認モード）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'バースト写真は削除されません。グループの整理状況を確認するだけです。やり直しが自由にできます。',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              'ON（削除モード）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.destructiveRed,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '⚠️ iOSの仕様上、バースト写真（連写の各フレーム）は「最近削除した項目」を経由せず直接完全削除されます。元に戻せません。',
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
                  : '$totalKeep枚のベストショットを確認します（写真は削除されません）。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _permanentlyDelete
                  ? '⚠️ iOSの仕様上、バースト写真は完全削除されます。元に戻せません。'
                  : '「実際に削除する」をONにすると完全削除できます。',
              style: TextStyle(
                fontSize: 13,
                color: _permanentlyDelete
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.secondaryLabel,
              ),
            ),
            if (_permanentlyDelete) ...[
              const SizedBox(height: 6),
              const Text(
                'iOSの確認ダイアログが表示されます。「削除」をタップして許可してください。',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
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
            child: Text(_permanentlyDelete ? '完全削除する' : '確認する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 確認モード（非削除）: ダイアログ表示のみ、グループを再読込
    if (!_permanentlyDelete) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('確認完了'),
          content: Text(
            '$totalKeep枚のベストショットを確認しました。\n実際に削除するには「実際に削除する」をONにしてください。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 全グループの ID をまとめて1回の API 呼び出しに集約
    // （グループごとに呼ぶと iOS 確認ダイアログがグループ数だけ出てしまうため）
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
        final ok = await widget.service.deleteAssets(allIdsToDelete);
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
              ? '$totalKeep枚を残して$deletedCount枚を完全削除しました。'
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
                ? '⚠️ iOSの仕様上、バースト写真は完全削除されます（元に戻せません）'
                : '確認モード：写真は削除されません。内容を確認できます。',
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
