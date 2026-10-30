// Platform boundary for similar-videos frame sampling (fix
// plan Stage 6, ADR-021), in the same shape as
// [MediaEnumerationGateway]: the scanner talks to the platform
// only through this seam, so host tests inject a fake and prove
// the scan's video-pass behaviour (gate, sequencing,
// cancellation) without a platform channel.
//
// The production gateway is wipe.'s OWN native frame grabber
// (VideoFrameChannel.kt, registered by MainActivity):
// photo_manager's video support returns a poster frame, not
// frames at chosen timestamps, and the sampling rule lives or
// dies by its timestamps — the same "small native piece of our
// own" the plan allowed for Stage 2's enumeration.

import 'package:flutter/services.dart';

/// Frame source for the similar-videos check. Both methods are
/// per-video and failure-soft: an unreadable video yields null /
/// null frames, never a throw — one bad file must not fail a
/// library scan.
abstract class VideoFrameGateway {
  /// The video's duration, or null when it cannot be read
  /// (missing, corrupt, or no duration metadata). The Stage 2
  /// enumeration carries no duration, so it is read through
  /// this channel — from the same platform retriever the
  /// frames come from.
  Future<Duration?> videoDuration(String assetId);

  /// One entry per requested timestamp, in request order: the
  /// frame at that time as PNG bytes of an exactly 9x8 raster,
  /// or null when that single frame could not be read. The 9x8
  /// raster is deliberate — the Dart side feeds these bytes
  /// through the photo fingerprint code unchanged
  /// (thumbnail_analysis.dart), whose difference hash consumes
  /// a 9x8 raster.
  Future<List<Uint8List?>> extractFrames(
    String assetId,
    List<Duration> timestamps,
  );
}

/// Production gateway over the app's own MethodChannel (see
/// the Kotlin side for the contract). Any platform error maps
/// to "unreadable" for that call: null duration, or a null for
/// every requested frame.
class NativeVideoFrameGateway implements VideoFrameGateway {
  const NativeVideoFrameGateway();

  static const MethodChannel _channel = MethodChannel(
    'mobile.wipe.app/video_frames',
  );

  @override
  Future<Duration?> videoDuration(String assetId) async {
    try {
      final int? microseconds = await _channel.invokeMethod<int>(
        'getDuration',
        <String, Object?>{'assetId': assetId},
      );
      if (microseconds == null || microseconds <= 0) {
        return null;
      }
      return Duration(microseconds: microseconds);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Uint8List?>> extractFrames(
    String assetId,
    List<Duration> timestamps,
  ) async {
    List<Uint8List?> unreadable() =>
        List<Uint8List?>.filled(timestamps.length, null);
    if (timestamps.isEmpty) {
      return const <Uint8List?>[];
    }
    try {
      final List<dynamic>? raw = await _channel.invokeListMethod<dynamic>(
        'extractFrames',
        <String, Object?>{
          'assetId': assetId,
          'timestampsUs': <int>[
            for (final Duration t in timestamps) t.inMicroseconds,
          ],
        },
      );
      if (raw == null) {
        return unreadable();
      }
      return <Uint8List?>[for (final Object? entry in raw) entry as Uint8List?];
    } catch (_) {
      return unreadable();
    }
  }
}
