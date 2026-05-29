import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/burst_group.dart';

/// saveAndDeleteBurst の結果。
enum SaveDeleteResult {
  /// 保存・削除が完了した。
  success,

  /// iOS の削除確認ダイアログでユーザーがキャンセルした（重複は発生しない）。
  cancelled,

  /// 失敗した（保存も削除も行われていない）。
  failed,
}

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

  Future<Uint8List?> getAssetThumbnail(String assetId, {int size = 300}) async {
    final raw = await _channel.invokeMethod(
      'getAssetThumbnail',
      {'assetId': assetId, 'size': size},
    );
    if (raw is Uint8List) return raw;
    return null;
  }

  /// 選択した [keepIds] をオリジナル品質の独立した写真として保存し、
  /// 同時にバースト全体 [burstIds] を削除する（ネイティブ側でアトミックに実行）。
  ///
  /// 保存と削除が 1 つのトランザクションになっているため、ユーザーが
  /// iOS の削除確認をキャンセルすると保存もまとめて取り消され、重複は発生しない。
  Future<SaveDeleteResult> saveAndDeleteBurst({
    required List<String> keepIds,
    required List<String> burstIds,
  }) async {
    if (keepIds.isEmpty || burstIds.isEmpty) return SaveDeleteResult.failed;
    try {
      final ok = await _channel.invokeMethod<bool>('saveAndDeleteBurst', {
        'keepIds': keepIds,
        'burstIds': burstIds,
      });
      return ok == true ? SaveDeleteResult.success : SaveDeleteResult.failed;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') return SaveDeleteResult.cancelled;
      return SaveDeleteResult.failed;
    }
  }
}
