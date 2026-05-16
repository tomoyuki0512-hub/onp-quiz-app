import 'dart:typed_data';
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

  Future<Uint8List?> getAssetThumbnail(String assetId, {int size = 300}) async {
    final raw = await _channel.invokeMethod(
      'getAssetThumbnail',
      {'assetId': assetId, 'size': size},
    );
    if (raw is Uint8List) return raw;
    return null;
  }

  Future<bool> saveAssetsAsCopies(List<String> ids) async {
    if (ids.isEmpty) return true;
    final result = await _channel.invokeMethod<bool>(
      'saveAssetsAsCopies',
      {'assetIds': ids},
    );
    return result ?? false;
  }

  Future<bool> deleteAssets(List<String> ids) async {
    if (ids.isEmpty) return true;
    final result = await _channel.invokeMethod<bool>(
      'deleteAssets',
      {'assetIds': ids},
    );
    return result ?? false;
  }
}
