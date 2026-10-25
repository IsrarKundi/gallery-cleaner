// Generation guard for fire-and-forget async work whose result
// must only land if it is still the latest request (solutions
// 5.2: off-isolate grouping that resolves after the user moved
// on, or after a newer regroup started).
//
// Usage: capture `final int generation = guard.next();` when
// launching the work, and apply the result only when
// `guard.isCurrent(generation)` still holds. Call [invalidate]
// in onClose so a result landing after disposal is dropped
// instead of touching a dead controller.

class AsyncGuard {
  int _generation = 0;

  /// Starts a new generation and returns its token. Any older
  /// token becomes stale at once.
  int next() => ++_generation;

  /// Invalidates every outstanding token without starting one.
  void invalidate() => _generation++;

  /// True when [generation] is still the latest token.
  bool isCurrent(int generation) => generation == _generation;
}
