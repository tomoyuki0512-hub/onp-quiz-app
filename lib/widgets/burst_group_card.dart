import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/burst_group.dart';

class BurstGroupCard extends StatelessWidget {
  final BurstGroup group;
  final VoidCallback onTap;

  const BurstGroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            _buildThumbnail(),
            const SizedBox(width: 14),
            Expanded(child: _buildInfo()),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(
        group.isRecentlyDeleted
            ? (group.assetIds.isNotEmpty ? group.assetIds.first : '')
            : (group.bestPickId ?? group.assetIds.first),
      ),
      builder: (context, snapshot) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 72,
            height: 72,
            color: CupertinoColors.systemGrey5,
            child: snapshot.hasData && snapshot.data != null
                ? _AssetThumbnail(asset: snapshot.data!)
                : const Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      color: CupertinoColors.systemGrey3,
                      size: 28,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (group.isRecentlyDeleted) ...[
              const Icon(
                CupertinoIcons.trash,
                size: 14,
                color: CupertinoColors.destructiveRed,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              group.isRecentlyDeleted ? '最近削除した項目' : 'バーストグループ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: group.isRecentlyDeleted
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${group.count}枚 · ${group.count - 1}枚を削除可能',
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        if (group.bestPickId != null) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'iOSのベストショットあり',
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.systemBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;

  const _AssetThumbnail({required this.asset});

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  late Future<Uint8List?> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(144, 144),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 72,
            height: 72,
          );
        }
        return const Center(
          child: CupertinoActivityIndicator(radius: 10),
        );
      },
    );
  }
}
