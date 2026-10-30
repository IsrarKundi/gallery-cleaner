// Cleanup's save pattern, shared by every JSON file write in
// the app (fix plan Stage 3, item 1; teardown notes/pipeline.md:
// "write <name>.json.tmp, flush(), getFD().sync(), renameTo
// target, copy-fallback on rename failure").
//
// 1. The new bytes go to `<target>.tmp` in the SAME directory
//    (so the rename below is always same-filesystem).
// 2. The temp file is flushed — dart:io's flush syncs the bytes
//    to disk, the `getFD().sync()` equivalent — and closed.
// 3. The temp file is renamed over the target: one atomic
//    directory operation, so a crash or kill at any point leaves
//    either the old file or the new file whole — never a
//    truncated target.
// 4. If the rename itself fails (Android's renameTo returns
//    false on some filesystems instead of throwing), the temp
//    file is COPIED over the target and then removed — the
//    copy is not atomic, but it only runs where the atomic
//    path was refused, and a leftover `.tmp` is harmless
//    (ignored on load, overwritten by the next write).

import 'dart:io';

/// Renames [tmp] over [target]. Injectable so tests can force
/// the failure Android's renameTo reports as `false` (Dart
/// surfaces it as a thrown [FileSystemException]) and prove
/// the copy fallback lands the bytes.
typedef AtomicRename = Future<void> Function(File tmp, File target);

class AtomicFileWriter {
  const AtomicFileWriter({this._rename});

  final AtomicRename? _rename;

  /// Atomically replaces [target]'s contents with [text]
  /// (UTF-8), per the steps in the file doc. Throws only when
  /// both the rename AND the copy fallback fail — callers keep
  /// their in-memory snapshot in that case (see JsonFileStore).
  Future<void> write(File target, String text) async {
    final File tmp = File('${target.path}.tmp');
    final RandomAccessFile raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeString(text);
      await raf.flush();
    } finally {
      await raf.close();
    }
    try {
      final AtomicRename rename = _rename ?? _defaultRename;
      await rename(tmp, target);
    } catch (_) {
      // Rename refused: copy the synced temp file over the
      // target instead (Cleanup's fallback), then remove the
      // temp file. A failed removal is not fatal — the next
      // write overwrites the leftover.
      await tmp.copy(target.path);
      try {
        await tmp.delete();
      } catch (_) {
        // Leftover .tmp: ignored on load, overwritten next write.
      }
    }
  }

  static Future<void> _defaultRename(File tmp, File target) async {
    await tmp.rename(target.path);
  }
}
