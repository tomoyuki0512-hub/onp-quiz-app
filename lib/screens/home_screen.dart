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
  bool _includeRecentlyDeleted = false;

  static const _segmentValues = {0: 2, 1: 5, 2: 10};

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
      final groups = await widget.service.getBurstGroups(
        includeRecentlyDeleted: _includeRecentlyDeleted,
      );
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

  int get _recentlyDeletedGroupCount {
    return _filteredGroups.where((g) => g.isRecentlyDeleted).length;
  }

  Future<void> _runAutoClean() async {
    final groups = _filteredGroups;
    if (groups.isEmpty) return;

    final totalDelete = _totalDeletable;
    final totalKeep = groups.length;
    final rdCount = _recentlyDeletedGroupCount;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('おまかせクリーン'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '$totalKeep枚を残し、$totalDelete枚を削除します。',
              style: const TextStyle(fontSize: 15),
            ),
            if (rdCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '⚠️ 最近削除した項目から$rdCount グループを完全削除します（元に戻せません）。',
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              rdCount == 0
                  ? '削除した写真は「最近削除した項目」に30日間残ります。'
                  : '通常ライブラリの写真は「最近削除した項目」へ移動します。',
              style: const TextStyle(
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
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    int deletedCount = 0;
    int errorCount = 0;

    for (final group in groups) {
      final idsToDelete = group.assetIds
          .where((id) => id != group.autoPickId)
          .toList();
      try {
        bool success;
        if (group.isRecentlyDeleted) {
          success = await widget.service.permanentlyDeleteAssets(idsToDelete);
        } else {
          success = await widget.service.deleteAssets(idsToDelete);
        }
        if (success) deletedCount += idsToDelete.length;
      } catch (_) {
        errorCount++;
      }
    }

    await _loadGroups();

    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('完了！'),
        content: Text(
          errorCount == 0
              ? '$totalKeep枚を残して$deletedCount枚を削除しました。'
              : '$deletedCount枚を削除しました（$errorCount件のエラーがありました）。',
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
            '対象グループ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _segmentValues.entries
                .firstWhere((e) => e.value == _minCount,
                    orElse: () => const MapEntry(0, 2))
                .key,
            children: const {
              0: Text('すべて (2枚+)'),
              1: Text('5枚以上'),
              2: Text('10枚以上'),
            },
            onValueChanged: (v) {
              if (v != null) {
                setState(() => _minCount = _segmentValues[v]!);
              }
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  '最近削除した項目も対象にする',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              CupertinoSwitch(
                value: _includeRecentlyDeleted,
                onChanged: (v) {
                  setState(() => _includeRecentlyDeleted = v);
                  _loadGroups();
                },
              ),
            ],
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

    final rdCount = _recentlyDeletedGroupCount;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${groups.length}', 'グループ'),
              Container(
                width: 1,
                height: 36,
                color: CupertinoColors.separator,
              ),
              _statItem('$_totalDeletable', '削除可能枚数'),
              if (rdCount > 0) ...[
                Container(
                  width: 1,
                  height: 36,
                  color: CupertinoColors.separator,
                ),
                _statItem('$rdCount', '最近削除'),
              ],
            ],
          ),
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
