package mobile.wipe.app

import android.content.ContentResolver
import android.database.Cursor
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Wipe.'s own one-pass library enumeration (fix plan Stage 2,
 * ADR-017; enumeration rules revised in ADR-026). photo_manager
 * 3.12 cannot return a file's size in the same pass as the asset
 * list (its entity map has no size field; `fileSize` is one
 * ContentResolver query per id), so the list pass lives here
 * instead: ONE MediaStore query per media type, returning every
 * field the Dart side needs — id, display name, bucket id/name,
 * size, dimensions, date added/taken/modified, favourite flag,
 * relative path.
 *
 * The row semantics follow Cleanup's enumerator (teardown
 * notes/pipeline.md Q1), not a plugin's cursor conversion:
 * - rows carry the MediaStore cursor values AS-IS. Width and
 *   height are the stored columns, zeroes included — nothing is
 *   repaired, and NO file is ever opened during enumeration:
 *   no header decode, no metadata retriever. Cleanup's asset
 *   records take `originalSize` straight from the cursor the
 *   same way. (ADR-017 §4 originally mirrored photo_manager's
 *   header repair; on a real library that repair opened files
 *   inside the cursor loop and could stall the whole pass —
 *   ADR-026 removed it on purpose.)
 * - rows whose backing file no longer exists are FLAGGED
 *   (`fileExists=false` — a stat, never an open), not dropped
 *   here; Dart drops them for asset lists.
 * - the RAW store dimensions ride along (`storeWidth` /
 *   `storeHeight`): the plugin's paged lists excluded images
 *   whose store WIDTH or HEIGHT was 0 (its size condition,
 *   which wipe. never ignored), so Dart applies that rule at
 *   list level from the raw columns. Id resolution never
 *   applies it: the plugin's per-id path was unfiltered. With
 *   the repair gone, `width`/`height` now always equal the
 *   store columns; both fields stay because the Dart rule is
 *   written on the raw ones.
 * - the two type passes run CONCURRENTLY on a small pool, as
 *   Cleanup fans its per-type queries out on one scope — Dart
 *   asks for both at once and can consume the images pass
 *   before the videos pass lands (ADR-026).
 * - sort is `_id DESC` per pass, the plugin's default order
 *   (its Dart FilterOptionGroup carries no explicit orders, and
 *   empty orders fall back to `_id DESC` natively); Dart merges
 *   the two passes by id, which reproduces the mixed-type order.
 *
 * No file content is read at all; no photo bytes ever cross
 * this channel.
 */
class MediaEnumerationChannel(
    private val resolver: ContentResolver,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "mobile.wipe.app/media_enumeration"
        private const val METHOD_IMAGES = "enumerateImages"
        private const val METHOD_VIDEOS = "enumerateVideos"
    }

    // Two threads: one per media type, so the images and videos
    // passes genuinely overlap instead of queueing behind each
    // other (ADR-026; Cleanup fans its queries out the same way).
    private val executor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_IMAGES -> enumerate(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, result)
            METHOD_VIDEOS -> enumerate(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, result)
            else -> result.notImplemented()
        }
    }

    private fun enumerate(
        uri: android.net.Uri,
        result: MethodChannel.Result,
    ) {
        executor.execute {
            try {
                val rows = query(uri)
                mainHandler.post { result.success(rows) }
            } catch (e: Exception) {
                // No exception text crosses the channel: Dart maps
                // any error to its generic media-load failure key.
                mainHandler.post { result.error("enumeration_failed", null, null) }
            }
        }
    }

    private fun query(uri: android.net.Uri): List<Map<String, Any?>> {
        val columns = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.BUCKET_ID,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DATA,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            columns.add(MediaStore.MediaColumns.RELATIVE_PATH)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            columns.add(MediaStore.MediaColumns.IS_FAVORITE)
        }
        val rows = ArrayList<Map<String, Any?>>()
        resolver.query(
            uri,
            columns.toTypedArray(),
            // Mirrors the plugin's whole-library album selection.
            "${MediaStore.MediaColumns.BUCKET_ID} IS NOT NULL",
            null,
            "${MediaStore.MediaColumns._ID} DESC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(row(cursor))
            }
        }
        return rows
    }

    private fun row(cursor: Cursor): Map<String, Any?> {
        fun long(column: String): Long {
            val index = cursor.getColumnIndex(column)
            return if (index >= 0) cursor.getLong(index) else 0L
        }
        fun int(column: String): Int {
            val index = cursor.getColumnIndex(column)
            return if (index >= 0) cursor.getInt(index) else 0
        }
        fun string(column: String): String? {
            val index = cursor.getColumnIndex(column)
            return if (index >= 0) cursor.getString(index) else null
        }

        // Cursor values as-is (ADR-026): a stored zero stays a
        // zero. Nothing here opens the file — the only file
        // touch in the whole pass is the exists() stat below.
        val storeWidth = int(MediaStore.MediaColumns.WIDTH)
        val storeHeight = int(MediaStore.MediaColumns.HEIGHT)
        val data = string(MediaStore.MediaColumns.DATA)
        return mapOf(
            "id" to long(MediaStore.MediaColumns._ID),
            "title" to (string(MediaStore.MediaColumns.DISPLAY_NAME) ?: ""),
            "bucketId" to long(MediaStore.MediaColumns.BUCKET_ID),
            "bucketName" to (string(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME) ?: ""),
            "sizeBytes" to long(MediaStore.MediaColumns.SIZE),
            "width" to storeWidth,
            "height" to storeHeight,
            "storeWidth" to storeWidth,
            "storeHeight" to storeHeight,
            // DATE_ADDED / DATE_MODIFIED are seconds, DATE_TAKEN
            // is milliseconds — the units MediaStore stores; Dart
            // converts exactly as the plugin's entity getters did.
            "dateAddedSec" to long(MediaStore.MediaColumns.DATE_ADDED),
            "dateTakenMs" to long(MediaStore.MediaColumns.DATE_TAKEN),
            "dateModifiedSec" to long(MediaStore.MediaColumns.DATE_MODIFIED),
            "isFavorite" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                int(MediaStore.MediaColumns.IS_FAVORITE) == 1),
            "relativePath" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                string(MediaStore.MediaColumns.RELATIVE_PATH)
            } else {
                null
            },
            // The plugin skipped rows whose file is gone (blank
            // paths were NOT skipped); Dart applies the same rule.
            "fileExists" to (data.isNullOrBlank() || File(data).exists()),
        )
    }
}
