import 'package:flutter/services.dart';
import '../models/burst_group.dart';

class BurstPhotoService {
  static const _channel = MethodChannel('com.example.photo_deleter/burst');

  Future<String> requestPermission() async {
    final status = await _channel.invokeMethod<String>('requestPermission');
    return status ?? 'unknown';
  }

  Future<List<BurstGroup>> getBurstGroups() async {
    final raw = await _channel.invokeMethod<List>('getBurstGroups');
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

  /// 最近削除した項目をすべて完全削除する。削除した枚数を返す
  Future<int> emptyRecentlyDeleted() async {
    final result = await _channel.invokeMethod<int>('emptyRecentlyDeleted');
    return result ?? 0;
  }

  /// バースト写真（非代表写真含む）のサムネイルとメタデータを取得する
  Future<Map<String, dynamic>?> getAssetData(
    String assetId, {
    int size = 1080,
  }) async {
    final raw = await _channel.invokeMethod(
      'getAssetData',
      {'assetId': assetId, 'size': size},
    );
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }
}
