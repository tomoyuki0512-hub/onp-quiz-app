import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';
import '../services/burst_photo_service.dart';
import 'burst_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final BurstPhotoService service;

  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BurstGroup> _groups = [];
  bool _isLoading = false;
  String _permissionStatus = 'notDetermined';

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

  Future<void> _openGroup(BurstGroup group) async {
    final deleted = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => BurstDetailScreen(group: group, service: widget.service),
      ),
    );
    if (deleted == true && mounted) await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isLoading ? '読み込み中...' : 'バースト写真 (${_groups.length}件)'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _loadGroups,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(child: _buildBody()),
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
            SizedBox(height: 12),
            Text(
              'フォトライブラリを確認中...',
              style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      );
    }
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.photo_on_rectangle, size: 64, color: CupertinoColors.systemGrey3),
            const SizedBox(height: 16),
            const Text('バースト写真が見つかりませんでした',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            CupertinoButton(onPressed: _loadGroups, child: const Text('再スキャン')),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) => _BurstGroupRow(
        group: _groups[index],
        service: widget.service,
        onTap: () => _openGroup(_groups[index]),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.lock_shield, size: 64, color: CupertinoColors.systemGrey3),
            const SizedBox(height: 16),
            const Text('フォトライブラリへのアクセスが必要です',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('設定アプリでアクセスを許可してください。',
                style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CupertinoButton.filled(onPressed: _initialize, child: const Text('再確認する')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BurstGroupRow extends StatefulWidget {
  final BurstGroup group;
  final BurstPhotoService service;
  final VoidCallback onTap;

  const _BurstGroupRow({
    required this.group,
    required this.service,
    required this.onTap,
  });

  @override
  State<_BurstGroupRow> createState() => _BurstGroupRowState();
}

class _BurstGroupRowState extends State<_BurstGroupRow> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // 一覧のサムネイルは「写りの良い1枚」（代表フレーム）を表示する。
    final thumb = await widget.service.getAssetThumbnail(
      widget.group.representativeId ?? widget.group.assetIds.first,
      size: 144,
    );
    if (mounted) setState(() => _thumbnail = thumb);
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y/$mo/$d $h:$mi:$s';
  }

  String _formatLocation(double lat, double lng) {
    final latStr = '${lat >= 0 ? 'N' : 'S'}${lat.abs().toStringAsFixed(4)}';
    final lngStr = '${lng >= 0 ? 'E' : 'W'}${lng.abs().toStringAsFixed(4)}';
    return '$latStr $lngStr';
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: CupertinoColors.systemGrey5,
                child: _thumbnail != null
                    ? Image.memory(_thumbnail!, fit: BoxFit.cover, width: 64, height: 64)
                    : const Center(child: CupertinoActivityIndicator(radius: 10)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group.createdAt != null)
                    Text(
                      _formatDate(group.createdAt!),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.count}枚',
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                  ),
                  if (group.latitude != null && group.longitude != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.location_solid,
                            size: 12, color: CupertinoColors.systemGrey),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _formatLocation(group.latitude!, group.longitude!),
                            style: const TextStyle(
                                fontSize: 12, color: CupertinoColors.systemGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: CupertinoColors.systemGrey3),
          ],
        ),
      ),
    );
  }
}
