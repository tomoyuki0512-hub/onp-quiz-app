import 'package:flutter/services.dart';
import '../models/burst_group.dart';

class BurstPhotoService {
  static const _channel = MethodChannel('com.example.photo_deleter/burst');

  Future<String> requestPermission() async {
    final status = await _channel.invokeMethod<String>('requestPermission');
    return status ?? 'unknown';
  }

  Future<List<BurstGroup>> getBurstGroups({
    bool includeRecentlyDeleted = false,
  }) async {
    final raw = await _channel.invokeMethod<List>('getBurstGroups', {
      'includeRecentlyDeleted': includeRecentlyDeleted,
    });
    if (raw == null) return [];
    return raw
        .map((e) => BurstGroup.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 通常ライブラリの写真を「最近削除した項目」へ移動する
  Future<bool> deleteAssets(List<String> idsToDelete) async {
    if (idsToDelete.isEmpty) return true;
    final result = await _channel.invokeMethod<bool>(
      'deleteAssets',
      {'assetIds': idsToDelete},
    );
    return result ?? false;
  }

  /// 「最近削除した項目」から完全削除する（元に戻せない）
  Future<bool> permanentlyDeleteAssets(List<String> idsToDelete) async {
    if (idsToDelete.isEmpty) return true;
    final result = await _channel.invokeMethod<bool>(
      'permanentlyDeleteAssets',
      {'assetIds': idsToDelete},
    );
    return result ?? false;
  }
}
