// Analysis batch workers (fix plan Stage 4): per-page
// fingerprint and blur batches run off the UI isolate.
//
// Pure Dart only — no platform channels, no Flutter imports — so
// this file is safe on a background isolate. The scanner fetches
// thumbnails on the main isolate (photo_manager lives there) and
// hands only bytes across; the workers decode and compute and
// hand back fingerprints / blur measures. No photo content ever
// leaves the device, and no decoded pixels leave this file.
//
// Per-asset degradation: one asset's bad bytes (or an unexpected
// decode error) yields null for that asset only, never a failed
// batch. A whole-batch failure (isolate spawn failure) is the
// scanner's problem: it falls back to the sync variants on the
// UI thread and reports the degraded state, never a hang. Sync
// and isolate outputs are identical for identical inputs — both
// run the same functions.

import 'dart:isolate';
import 'dart:typed_data';

import 'blur_detection.dart';
import 'thumbnail_analysis.dart';

/// One asset's input to a batch run: thumbnail bytes, transferred
/// (not copied) across the isolate boundary; may be materialized
/// exactly once, on whichever isolate runs the batch.
class AnalysisBatchInput {
  const AnalysisBatchInput({required this.assetId, required this.bytes});

  final String assetId;
  final TransferableTypedData bytes;
}

/// A fingerprint batch runner of this shape, so the scanner can
/// inject a failing runner in tests to prove the degraded
/// fallback.
typedef FingerprintBatchRunner = Future<List<FingerprintComputation?>> Function(
  List<AnalysisBatchInput> inputs,
);

/// A blur batch runner of this shape (same reasoning).
typedef BlurBatchRunner = Future<List<BlurAssessment?>> Function(
  List<AnalysisBatchInput> inputs,
);

/// Production fingerprint runner: one [Isolate.run] per batch
/// (never per photo — spawn/copy overhead would exceed the
/// saving). The batch is bounded by the scanner's page size.
Future<List<FingerprintComputation?>> fingerprintBatchOnIsolate(
  List<AnalysisBatchInput> inputs,
) {
  return Isolate.run(() => fingerprintBatchSync(inputs));
}

/// Production blur runner: one [Isolate.run] per batch. Blur
/// batches are bounded by the scanner's fetch concurrency (8),
/// matching Cleanup's separate-pass parallelism cap.
Future<List<BlurAssessment?>> blurBatchOnIsolate(
  List<AnalysisBatchInput> inputs,
) {
  return Isolate.run(() => blurBatchSync(inputs));
}

/// Synchronous fingerprint batch (the worker body + the
/// scanner's UI-thread fallback).
List<FingerprintComputation?> fingerprintBatchSync(
  List<AnalysisBatchInput> inputs,
) {
  return inputs.map((AnalysisBatchInput input) {
    try {
      final Uint8List bytes = input.bytes.materialize().asUint8List();
      return computeFingerprint(bytes);
    } catch (_) {
      return null;
    }
  }).toList();
}

/// Synchronous blur batch (the worker body + the fallback).
List<BlurAssessment?> blurBatchSync(List<AnalysisBatchInput> inputs) {
  return inputs.map((AnalysisBatchInput input) {
    try {
      final Uint8List bytes = input.bytes.materialize().asUint8List();
      return computeBlur(bytes);
    } catch (_) {
      return null;
    }
  }).toList();
}
