import '../models/burst_group.dart';

class BurstPhotoService {
  Future<String> requestPermission() async => 'unknown';

  Future<List<BurstGroup>> getBurstGroups() async => [];

  Future<bool> deleteAssets(List<String> ids) async => false;

  Future<bool> permanentlyDeleteAssets(List<String> ids) async => false;

  Future<int> emptyRecentlyDeleted() async => 0;

  Future<Map<String, dynamic>?> getAssetData(String assetId, {int size = 1080}) async => null;
}
