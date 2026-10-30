// [ReviewGateway] over the `in_app_review` plugin (Play
// In-App Review — the same stack Cleanup ships, teardown
// notes/retention.md §4.3). Every call is best-effort: a device
// without the store, a sideloaded build, or a plugin error all
// read as "unavailable" / no-op, because the ask flow must
// degrade silently (ADR-020 decision 10).

import 'package:in_app_review/in_app_review.dart';

import 'review_gateway.dart';

class ReviewGatewayImpl implements ReviewGateway {
  ReviewGatewayImpl({InAppReview? plugin})
    : _plugin = plugin ?? InAppReview.instance;

  final InAppReview _plugin;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _plugin.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestReview() async {
    try {
      await _plugin.requestReview();
    } catch (_) {
      // Best effort: the ask is already marked answered by the
      // caller; a failed request must never surface as an error.
    }
  }

  @override
  Future<void> openStoreListing() async {
    try {
      await _plugin.openStoreListing();
    } catch (_) {
      // Same best-effort rule as [requestReview].
    }
  }
}
