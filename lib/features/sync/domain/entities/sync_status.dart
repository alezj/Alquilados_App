class SyncStatus {
  const SyncStatus({
    required this.isRunning,
    required this.message,
    required this.lastUpdatedAt,
    this.localChanges = 0,
  });

  final bool isRunning;
  final String message;
  final DateTime? lastUpdatedAt;
  final int localChanges;

  SyncStatus copyWith({
    bool? isRunning,
    String? message,
    DateTime? lastUpdatedAt,
  }) {
    return SyncStatus(
      isRunning: isRunning ?? this.isRunning,
      message: message ?? this.message,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      localChanges: localChanges,
    );
  }
}
