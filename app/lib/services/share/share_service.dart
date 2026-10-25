// Sharing a session summary (Phase 2B).
//
// Interface only. The implementation shares the summary-card PNG
// (captured by the view via RepaintBoundary) plus the summary text
// through the platform share sheet (`share_plus`, resolved as
// 13.3.1 on Flutter 3.47.7). When no image is supplied it shares
// the text alone — that is the documented fallback when capture
// fails. The platform share call itself is not unit-testable on
// this host; tests cover the shared data (summary + text), not
// the sheet.

import 'dart:typed_data';

import '../../core/utils/result.dart';

abstract class ShareService {
  /// Shares [text], plus [imagePng] when supplied. Returns success
  /// when the sheet was shown (the platform does not guarantee the
  /// user actually shared); failures carry a string key.
  Future<Result<void>> shareSummary({
    required String text,
    Uint8List? imagePng,
  });
}
