class SyncStatus {
  const SyncStatus({
    required this.isRunning,
    required this.message,
    required this.lastUpdatedAt,
  });

  final bool isRunning;
  final String message;
  final DateTime? lastUpdatedAt;

  SyncStatus copyWith({
    bool? isRunning,
    String? message,
    DateTime? lastUpdatedAt,
  }) {
    return SyncStatus(
      isRunning: isRunning ?? this.isRunning,
      message: message ?? this.message,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
