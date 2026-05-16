import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';

class BurstDetailScreen extends StatefulWidget {
  final BurstGroup group;
  final BurstPhotoService service;

  const BurstDetailScreen({
    super.key,
    required this.group,
    required this.service,
  });

  @override
  State<BurstDetailScreen> createState() => _BurstDetailScreenState();
}

class _BurstDetailScreenState extends State<BurstDetailScreen> {
  final Set<String> _selected = {};
  bool _isProcessing = false;

  Future<void> _saveAndDeleteBurst() async {
    if (_selected.isEmpty) {
      _showDialog('写真を選択してください', '保存する写真を1枚以上選択してください。');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('保存して削除'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '選択した${_selected.length}枚を通常の写真として保存し、'
              'バーストの全${widget.group.count}枚を削除します。',
            ),
            const SizedBox(height: 6),
            const Text(
              '保存後にiOSの確認ダイアログが表示されます。「削除」をタップしてください。',
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
            child: const Text('保存して削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // Step 1: 選択写真を通常の写真としてコピー保存
      final saved = await widget.service.saveAssetsAsCopies(_selected.toList());
      if (!mounted) return;
      if (!saved) {
        _showDialog('保存失敗', '写真の保存に失敗しました。削除は行いませんでした。');
        return;
      }

      // Step 2: バースト全体を削除
      final deleted = await widget.service.deleteAssets(widget.group.assetIds);
      if (!mounted) return;
      if (deleted) {
        Navigator.pop(context, true);
      } else {
        _showDialog(
          '削除失敗',
          '写真は保存されましたが、バーストの削除に失敗しました。',
        );
      }
    } catch (e) {
      if (mounted) _showDialog('エラー', '$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDialog(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
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
    final assetIds = widget.group.assetIds;
    final allSelected = _selected.length == assetIds.length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_selected.isEmpty
            ? '${widget.group.count}枚'
            : '${_selected.length}枚選択中'),
        trailing: _isProcessing
            ? const CupertinoActivityIndicator(radius: 10)
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: assetIds.length,
                itemBuilder: (context, index) {
                  final id = assetIds[index];
                  return _PhotoCell(
                    assetId: id,
                    service: widget.service,
                    isSelected: _selected.contains(id),
                    isRepresentative: id == widget.group.representativeId,
                    onTap: () => setState(() {
                      if (_selected.contains(id)) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    }),
                  );
                },
              ),
            ),
            _buildBottomBar(assetIds, allSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<String> assetIds, bool allSelected) {
    final canSave = _selected.isNotEmpty;

    final statusText = _selected.isEmpty
        ? '保存する写真をタップして選択してください'
        : '${_selected.length}枚を保存してバーストの${widget.group.count}枚を削除します';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 36,
                onPressed: () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected.addAll(assetIds);
                  }
                }),
                child: Text(
                  allSelected ? '全解除' : '全選択',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: canSave && !_isProcessing ? _saveAndDeleteBurst : null,
                  borderRadius: BorderRadius.circular(12),
                  child: const Text(
                    '選択を保存してバーストを削除',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PhotoCell extends StatefulWidget {
  final String assetId;
  final BurstPhotoService service;
  final bool isSelected;
  final bool isRepresentative;
  final VoidCallback onTap;

  const _PhotoCell({
    required this.assetId,
    required this.service,
    required this.isSelected,
    required this.isRepresentative,
    required this.onTap,
  });

  @override
  State<_PhotoCell> createState() => _PhotoCellState();
}

class _PhotoCellState extends State<_PhotoCell> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.service.getAssetThumbnail(widget.assetId, size: 400);
    if (mounted) setState(() => _thumbnail = data);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: CupertinoColors.systemGrey5,
            child: _thumbnail != null
                ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                : const Center(child: CupertinoActivityIndicator(radius: 10)),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: widget.isSelected ? 1.0 : 0.0,
            child: Container(
              color: CupertinoColors.systemBlue.withOpacity(0.3),
            ),
          ),
          if (widget.isRepresentative)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemYellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '★',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? CupertinoColors.systemBlue
                    : const Color(0x00000000),
                border: Border.all(
                  color: widget.isSelected
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.white,
                  width: 2,
                ),
              ),
              child: widget.isSelected
                  ? const Icon(CupertinoIcons.checkmark,
                      size: 14, color: CupertinoColors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
