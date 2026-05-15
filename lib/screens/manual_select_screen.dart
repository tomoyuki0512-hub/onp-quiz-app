import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';

class ManualSelectScreen extends StatefulWidget {
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
  State<ManualSelectScreen> createState() => _ManualSelectScreenState();
}

class _ManualSelectScreenState extends State<ManualSelectScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _keepCurrentPhoto() async {
    final keepId = widget.group.assetIds[_currentIndex];
    final idsToDelete =
        widget.group.assetIds.where((id) => id != keepId).toList();
    final deleteCount = idsToDelete.length;
    final permanently = widget.permanentlyDelete;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('この写真を残す'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'この写真を残して、他の$deleteCount枚を${permanently ? "完全削除" : "削除"}します。',
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
      bool success;
      if (permanently) {
        success = await widget.service.permanentlyDeleteAssets(idsToDelete);
      } else {
        success = await widget.service.deleteAssets(idsToDelete);
      }

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
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
    final group = widget.group;
    final count = group.count;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (group.isRecentlyDeleted) ...[
              const Icon(
                CupertinoIcons.trash,
                size: 14,
                color: CupertinoColors.destructiveRed,
              ),
              const SizedBox(width: 4),
            ],
            Text('バーストグループ ($count枚)'),
          ],
        ),
        trailing: _isDeleting
            ? const CupertinoActivityIndicator(radius: 10)
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: count,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  return _PhotoPage(
                    assetId: group.assetIds[index],
                    isBestPick: group.assetIds[index] == group.bestPickId,
                  );
                },
              ),
            ),
            _buildBottomBar(count),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentIndex + 1} / $count',
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildDotIndicator(count),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _isDeleting ? null : _keepCurrentPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.checkmark_circle, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'この写真を残す',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(int count) {
    const maxDots = 10;
    final showCount = count.clamp(0, maxDots);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(showCount, (i) {
        final isActive = i == _currentIndex.clamp(0, showCount - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 10 : 6,
          height: isActive ? 10 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isActive
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemGrey4,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _PhotoPage extends StatefulWidget {
  final String assetId;
  final bool isBestPick;

  const _PhotoPage({required this.assetId, required this.isBestPick});

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  late Future<(AssetEntity?, Uint8List?)> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadPhoto();
  }

  Future<(AssetEntity?, Uint8List?)> _loadPhoto() async {
    final entity = await AssetEntity.fromId(widget.assetId);
    if (entity == null) return (null, null);
    final data = await entity.thumbnailDataWithSize(
      const ThumbnailSize(1080, 1080),
      quality: 95,
    );
    return (entity, data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AssetEntity?, Uint8List?)>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator(radius: 16));
        }

        final (_, data) = snapshot.data!;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 48,
                  color: CupertinoColors.systemGrey3,
                ),
                const SizedBox(height: 12),
                const Text(
                  '写真を読み込めませんでした',
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: Image.memory(
                data,
                fit: BoxFit.contain,
              ),
            ),
            if (widget.isBestPick)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'iOSのおすすめ',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
