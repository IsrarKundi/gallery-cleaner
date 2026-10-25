// Decode-size helper (Phase 1.6, requirements §7).
//
// Returns the square side, in physical pixels, to decode a square
// thumbnail at for a container of [width] x [height] logical pixels
// on a screen with [devicePixelRatio], given the fetched thumbnail's
// [sourceSize]. The longest displayed edge governs (BoxFit.cover
// scales to it), and the decode never upscales: when the display
// needs more pixels than the source holds, the source size wins.
// Fetching a larger thumbnail is Phase 3's per-surface sizing, not
// this step's job. Unbounded or degenerate containers fall back to
// the source size, so no site can decode at an absurd size.
int decodeSide({
  required double width,
  required double height,
  required double devicePixelRatio,
  required int sourceSize,
}) {
  if (!width.isFinite || !height.isFinite) {
    return sourceSize;
  }
  final double longest = width > height ? width : height;
  final int physical = (longest * devicePixelRatio).round();
  if (physical <= 0) {
    return sourceSize;
  }
  return physical < sourceSize ? physical : sourceSize;
}
