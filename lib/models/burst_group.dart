class BurstGroup {
  final String burstId;
  final List<String> assetIds;
  final String? bestPickId;
  final bool isRecentlyDeleted;

  const BurstGroup({
    required this.burstId,
    required this.assetIds,
    this.bestPickId,
    this.isRecentlyDeleted = false,
  });

  factory BurstGroup.fromMap(Map<String, dynamic> map) {
    return BurstGroup(
      burstId: map['burstId'] as String,
      assetIds: List<String>.from(map['assetIds'] as List),
      bestPickId: map['bestPickId'] as String?,
      isRecentlyDeleted: map['isRecentlyDeleted'] as bool? ?? false,
    );
  }

  String get autoPickId {
    if (bestPickId != null) return bestPickId!;
    return assetIds[assetIds.length ~/ 2];
  }

  int get count => assetIds.length;
}
