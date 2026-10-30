// The store-prompt gateway (fix plan Stage 5, ADR-020
// decision 10): the one seam between the review ask and the
// Play in-app review API, so the service (and its tests) never
// touch the plugin. The implementation is the only file that
// imports `in_app_review`.

abstract class ReviewGateway {
  /// Whether the store can show its in-app review dialog here.
  /// The dialog's own outcome is never observable — availability
  /// is all the API reports before the request.
  Future<bool> isAvailable();

  /// Shows the store's review dialog. Fire-and-forget by API
  /// design: completion means the request was handed over, not
  /// that the user rated.
  Future<void> requestReview();

  /// Opens the app's store listing page — the graceful fallback
  /// when the in-app dialog is unavailable.
  Future<void> openStoreListing();
}
