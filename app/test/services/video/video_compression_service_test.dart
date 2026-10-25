// Video compression preview accounting (requirements §7, Phase 4
// + §4 three-state accounting): the saving is the compressed
// copy versus the original, never "freed" while the original
// still exists. These tests pin the preview math the UI renders;
// the native transcoding backend itself is host-untestable (no
// device, no MediaStore) and is an owner on-device check.

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/video/video_compression_service.dart';

VideoCompressionPreview preview(int original, int compressed) {
  return VideoCompressionPreview(
    original: MediaAsset(
      id: 'v1',
      type: MediaAssetType.video,
      width: 1920,
      height: 1080,
      sizeBytes: original,
      createDate: DateTime(2026, 10, 5),
      title: 'clip.mp4',
      albumName: 'Camera',
    ),
    originalBytes: original,
    compressedBytes: compressed,
    tempPath: '/cache/clip_compressed.mp4',
  );
}

void main() {
  test('smaller copy reports its saving', () {
    final VideoCompressionPreview p = preview(100000000, 40000000);
    expect(p.isSmaller, isTrue);
    expect(p.savingBytes, 60000000);
  });

  test('larger copy saves nothing and is not smaller', () {
    final VideoCompressionPreview p = preview(40000000, 50000000);
    expect(p.isSmaller, isFalse);
    expect(p.savingBytes, 0);
  });

  test('equal-size copy saves nothing and is not smaller', () {
    final VideoCompressionPreview p = preview(40000000, 40000000);
    expect(p.isSmaller, isFalse);
    expect(p.savingBytes, 0);
  });
}
