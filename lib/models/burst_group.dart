class BurstGroup {
  final String burstId;
  final List<String> assetIds;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;

  const BurstGroup({
    required this.burstId,
    required this.assetIds,
    this.createdAt,
    this.latitude,
    this.longitude,
  });

  int get count => assetIds.length;

  factory BurstGroup.fromMap(Map<String, dynamic> map) {
    final ts = map['createdAt'] as int?;
    return BurstGroup(
      burstId: map['burstId'] as String,
      assetIds: List<String>.from(map['assetIds'] as List),
      createdAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
