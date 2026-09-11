class MeshStatus {
  final bool isMeshActive;
  final int nearbyCount;
  final int batteryLevel;
  final int activeRelays;
  final bool isBroadcastingSOS;
  final DateTime lastSynced;

  const MeshStatus({
    this.isMeshActive = true,
    this.nearbyCount = 0,
    this.batteryLevel = 76,
    this.activeRelays = 0,
    this.isBroadcastingSOS = false,
    required this.lastSynced,
  });

  MeshStatus copyWith({
    bool? isMeshActive,
    int? nearbyCount,
    int? batteryLevel,
    int? activeRelays,
    bool? isBroadcastingSOS,
    DateTime? lastSynced,
  }) {
    return MeshStatus(
      isMeshActive: isMeshActive ?? this.isMeshActive,
      nearbyCount: nearbyCount ?? this.nearbyCount,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      activeRelays: activeRelays ?? this.activeRelays,
      isBroadcastingSOS: isBroadcastingSOS ?? this.isBroadcastingSOS,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}
