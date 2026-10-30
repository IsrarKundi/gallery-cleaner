package mobile.wipe.app

import android.content.ContentResolver
import android.database.Cursor
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
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
 * ADR-017). photo_manager 3.12 cannot return a file's size in the
 * same pass as the asset list (its entity map has no size field;
 * `fileSize` is one ContentResolver query per id), so the list
 * pass lives here instead: ONE MediaStore query per media type,
 * on a background executor, returning every field the Dart side
 * needs — id, display name, bucket id/name, size, dimensions,
 * date added/taken/modified, favourite flag, relative path.
 *
 * The row semantics deliberately mirror photo_manager's Android
 * cursor conversion, because the Dart side used to be fed by it:
 * - rows whose backing file no longer exists are FLAGGED
 *   (`fileExists=false`), not dropped here; Dart drops them,
 *   exactly as the plugin skipped them in paged lists;
 * - a zero width or height is repaired from the file header
 *   (bounds decode for images, metadata retriever for videos),
 *   as the plugin repaired it from EXIF/retriever;
 * - the RAW store dimensions ride along (`storeWidth` /
 *   `storeHeight`): the plugin's paged lists excluded images
 *   whose store WIDTH or HEIGHT was 0 (its size condition,
 *   which wipe. never ignored), so Dart applies that rule at
 *   list level from the raw columns — the repaired values
 *   alone cannot reproduce it. Id resolution never applies
 *   it: the plugin's per-id path was unfiltered;
 * - sort is `_id DESC` per pass, the plugin's default order
 *   (its Dart FilterOptionGroup carries no explicit orders, and
 *   empty orders fall back to `_id DESC` natively); Dart merges
 *   the two passes by id, which reproduces the mixed-type order.
 *
 * No file content is read beyond header metadata for the
 * zero-dimension repair; no photo bytes ever cross this channel.
 */
class MediaEnumerationChannel(
    private val resolver: ContentResolver,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "mobile.wipe.app/media_enumeration"
        private const val METHOD_IMAGES = "enumerateImages"
        private const val METHOD_VIDEOS = "enumerateVideos"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_IMAGES -> enumerate(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, result)
            METHOD_VIDEOS -> enumerate(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, false, result)
            else -> result.notImplemented()
        }
    }

    private fun enumerate(
        uri: android.net.Uri,
        isImage: Boolean,
        result: MethodChannel.Result,
    ) {
        executor.execute {
            try {
                val rows = query(uri, isImage)
                mainHandler.post { result.success(rows) }
            } catch (e: Exception) {
                // No exception text crosses the channel: Dart maps
                // any error to its generic media-load failure key.
                mainHandler.post { result.error("enumeration_failed", null, null) }
            }
        }
    }

    private fun query(uri: android.net.Uri, isImage: Boolean): List<Map<String, Any?>> {
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
            MediaStore.MediaColumns.MIME_TYPE,
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
                rows.add(row(cursor, isImage))
            }
        }
        return rows
    }

    private fun row(cursor: Cursor, isImage: Boolean): Map<String, Any?> {
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

        val storeWidth = int(MediaStore.MediaColumns.WIDTH)
        val storeHeight = int(MediaStore.MediaColumns.HEIGHT)
        var width = storeWidth
        var height = storeHeight
        val data = string(MediaStore.MediaColumns.DATA)
        if (width == 0 || height == 0) {
            val repaired = repairDimensions(data, isImage, string(MediaStore.MediaColumns.MIME_TYPE))
            if (repaired != null) {
                width = repaired.first
                height = repaired.second
            }
        }
        return mapOf(
            "id" to long(MediaStore.MediaColumns._ID),
            "title" to (string(MediaStore.MediaColumns.DISPLAY_NAME) ?: ""),
            "bucketId" to long(MediaStore.MediaColumns.BUCKET_ID),
            "bucketName" to (string(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME) ?: ""),
            "sizeBytes" to long(MediaStore.MediaColumns.SIZE),
            "width" to width,
            "height" to height,
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

    /**
     * Zero-dimension repair, mirroring the plugin's fallback:
     * images via header bounds (skipped for SVG, whose header has
     * no pixel size), videos via the metadata retriever. Any
     * failure keeps the cursor's zeroes.
     */
    private fun repairDimensions(
        data: String?,
        isImage: Boolean,
        mimeType: String?,
    ): Pair<Int, Int>? {
        if (data.isNullOrBlank()) {
            return null
        }
        return try {
            if (isImage) {
                if (mimeType?.contains("svg") == true) {
                    null
                } else {
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(data, options)
                    if (options.outWidth > 0 && options.outHeight > 0) {
                        options.outWidth to options.outHeight
                    } else {
                        null
                    }
                }
            } else {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(data)
                    val w = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH,
                    )?.toIntOrNull() ?: 0
                    val h = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT,
                    )?.toIntOrNull() ?: 0
                    if (w > 0 && h > 0) w to h else null
                } finally {
                    retriever.release()
                }
            }
        } catch (e: Exception) {
            null
        }
    }
}
