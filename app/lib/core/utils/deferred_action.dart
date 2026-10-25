/// Defers an action while a card exit animation is in flight
/// (solutions 3.2 settled-review gate): review navigation requested
/// mid-flight runs the moment the flight ends, instead of opening
/// review with a mark still unrecorded. At most one action waits; a
/// later request replaces an earlier one (navigation is idempotent —
/// the latest request is the one that matters).
class DeferredAction {
  bool _busy = false;
  void Function()? _pending;

  bool get isBusy => _busy;

  void setBusy(bool busy) {
    _busy = busy;
    if (!busy) {
      final void Function()? action = _pending;
      _pending = null;
      action?.call();
    }
  }

  void run(void Function() action) {
    if (_busy) {
      _pending = action;
    } else {
      action();
    }
  }
}
