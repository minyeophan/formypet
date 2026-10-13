typedef PetLogTempFileDelete = Future<bool> Function(String path);

/// Keeps temporary files registered until deletion succeeds.
class PetLogTempFileRegistry {
  final Set<String> _pendingPaths = {};
  Future<void>? _cleanupInProgress;

  Set<String> get pendingPaths => Set.unmodifiable(_pendingPaths);

  void register(String path) => _pendingPaths.add(path);

  Future<void> cleanupExcept(
    Set<String> retainedPaths,
    PetLogTempFileDelete delete,
  ) async {
    final removable = _pendingPaths
        .where((path) => !retainedPaths.contains(path))
        .toList();
    for (final path in removable) {
      try {
        if (await delete(path)) _pendingPaths.remove(path);
      } catch (_) {
        // Keep paths after transient filesystem errors so later cleanup retries.
      }
    }
  }

  Future<void> cleanup(PetLogTempFileDelete delete) async {
    final existing = _cleanupInProgress;
    if (existing != null) {
      await existing;
      if (_pendingPaths.isEmpty) return;
    }
    final future = _deletePending(delete);
    _cleanupInProgress = future;
    try {
      await future;
    } finally {
      if (identical(_cleanupInProgress, future)) _cleanupInProgress = null;
    }
  }

  Future<void> _deletePending(PetLogTempFileDelete delete) async {
    for (final path in List<String>.of(_pendingPaths)) {
      try {
        if (await delete(path)) _pendingPaths.remove(path);
      } catch (_) {
        // Keep paths after transient filesystem errors so a later cleanup retries.
      }
    }
  }
}
