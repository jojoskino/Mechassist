/// Évite les rafraîchissements API empilés (un seul en cours, un en attente max).
class RefreshCoordinator {
  bool _busy = false;
  bool _pending = false;

  Future<void> run(Future<void> Function() task) async {
    if (_busy) {
      _pending = true;
      return;
    }
    _busy = true;
    try {
      do {
        _pending = false;
        await task();
      } while (_pending);
    } finally {
      _busy = false;
    }
  }
}
