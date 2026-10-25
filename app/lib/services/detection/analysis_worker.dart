// Analysis batch worker (solutions 5.1): per-page thumbnail
// analysis runs off the UI isolate.
//
// Pure Dart only — no platform channels, no Flutter imports — so
// this file is safe on a background isolate. The scanner fetches
// thumbnails on the main isolate (photo_manager lives there) and
// hands only bytes + asset facts across; the worker decodes and
// scores them and hands back analyses. No photo content ever
// leaves the device, and no decoded pixels leave this file —
// only the hash and scores (see thumbnail_analysis.dart).
//
// Per-asset degradation: one asset's bad bytes (or an unexpected
// decode error) yields null for that asset only, never a failed
// batch. A whole-batch failure (isolate spawn failure) is the
// scanner's problem: it falls back to [analyzeBatchSync] on the
// UI thread and reports the degraded state, never a hang.

import 'dart:isolate';
import 'dart:typed_data';

import 'photo_analysis.dart';
import 'thumbnail_analysis.dart';

/// One asset's input to a batch analysis run: thumbnail bytes plus
/// the asset facts the analysis needs. [bytes] is transferred, not
/// copied, across the isolate boundary; it may be materialized
/// exactly once, on whichever isolate runs the batch.
class AnalysisBatchInput {
  const AnalysisBatchInput({
    required this.assetId,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String assetId;
  final TransferableTypedData bytes;
  final int width;
  final int height;
}

/// Runs a batch analysis on a worker isolate. A function of this
/// shape, so the scanner can inject a failing runner in tests to
/// prove the degraded fallback.
typedef AnalyzeBatchRunner = Future<List<PhotoAnalysis?>> Function(
  List<AnalysisBatchInput> inputs,
);

/// The production runner: one [Isolate.run] per page-batch (never
/// per photo — spawn/copy overhead would exceed the saving).
/// The batch is bounded by the scanner's page size, which is also
/// the memory cap: at most one page of small analysis thumbnails
/// is in flight at once.
Future<List<PhotoAnalysis?>> analyzeBatchOnIsolate(
  List<AnalysisBatchInput> inputs,
) {
  return Isolate.run(() => analyzeBatchSync(inputs));
}

/// Synchronous batch analysis: materialize each input's bytes and
/// run the exact same [analyzeThumbnail] the UI thread used to
/// run, with per-asset try/catch so one bad asset degrades to
/// null instead of failing the batch. Used by the isolate worker
/// above AND by the scanner's UI-thread fallback when isolate
/// spawn fails, so fallback outputs are identical to worker
/// outputs for the same inputs.
List<PhotoAnalysis?> analyzeBatchSync(List<AnalysisBatchInput> inputs) {
  return inputs.map((AnalysisBatchInput input) {
    try {
      final Uint8List bytes = input.bytes.materialize().asUint8List();
      return analyzeThumbnail(
        assetId: input.assetId,
        bytes: bytes,
        width: input.width,
        height: input.height,
      );
    } catch (_) {
      return null;
    }
  }).toList();
}
