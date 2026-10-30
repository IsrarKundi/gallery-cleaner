package mobile.wipe.app

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Wipe.'s own video frame grabber (fix plan Stage 6, ADR-021):
 * the frame source for the similar-videos check. photo_manager
 * can hand back a video's poster frame, but sampling needs
 * frames at CHOSEN timestamps, so — exactly like the Stage 2
 * enumeration — the platform call lives here, in our own code.
 *
 * Contract (see the Dart side, video_frame_gateway.dart):
 * - `getDuration(assetId)` -> the video's duration in
 *   microseconds, or -1 when the file carries none. The Stage 2
 *   enumeration carries no duration, so it is read here, from
 *   the same retriever the frames come from (metadata key 9 —
 *   the duration read the teardown found in Cleanup's own
 *   frame extraction).
 * - `extractFrames(assetId, timestampsUs)` -> one entry per
 *   requested timestamp, in order: the frame at that time
 *   (OPTION_CLOSEST_SYNC), scaled to exactly 9x8 px and
 *   PNG-encoded, or null when that frame could not be read.
 *   The 9x8 raster is the whole point: the Dart side feeds
 *   these bytes through the SAME fingerprint code as photos,
 *   whose difference hash consumes a 9x8 raster.
 *
 * All work runs on a single background executor: extraction
 * is sequential by design (the scan's expensive step is kept
 * tightly bounded), and calls therefore never interleave.
 * No frame bytes are stored or logged anywhere — they cross
 * the channel to Dart and are discarded after fingerprinting.
 */
class VideoFrameChannel(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "mobile.wipe.app/video_frames"
        private const val METHOD_DURATION = "getDuration"
        private const val METHOD_FRAMES = "extractFrames"
        private const val FRAME_WIDTH = 9
        private const val FRAME_HEIGHT = 8
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_DURATION -> {
                val assetId = call.argument<String>("assetId")
                if (assetId == null) {
                    result.error("video_frame_failed", null, null)
                    return
                }
                runAsync(result) { durationUs(assetId) }
            }
            METHOD_FRAMES -> {
                val assetId = call.argument<String>("assetId")
                val rawTimestamps = call.argument<List<*>>("timestampsUs")
                if (assetId == null || rawTimestamps == null) {
                    result.error("video_frame_failed", null, null)
                    return
                }
                val timestamps = rawTimestamps.mapNotNull { (it as? Number)?.toLong() }
                runAsync(result) { extractFrames(assetId, timestamps) }
            }
            else -> result.notImplemented()
        }
    }

    private fun <T> runAsync(result: MethodChannel.Result, work: () -> T) {
        executor.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                // No exception text crosses the channel (the
                // Stage 2 rule): Dart maps any error to "this
                // video is unreadable" and the scan moves on.
                mainHandler.post { result.error("video_frame_failed", null, null) }
            }
        }
    }

    private fun videoUri(assetId: String): android.net.Uri {
        return ContentUris.withAppendedId(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            assetId.toLong(),
        )
    }

    /** Opens a retriever on the video's content URI (scoped
     * storage safe: the retriever reads through the resolver).
     * If [MediaMetadataRetriever.setDataSource] itself throws,
     * the retriever has no owner yet, so the finally below
     * releases it; on success the caller's finally owns the
     * release. Every path releases exactly once. */
    private fun openRetriever(assetId: String): MediaMetadataRetriever {
        val retriever = MediaMetadataRetriever()
        var opened = false
        try {
            retriever.setDataSource(context, videoUri(assetId))
            opened = true
        } finally {
            if (!opened) releaseQuietly(retriever)
        }
        return retriever
    }

    private fun releaseQuietly(retriever: MediaMetadataRetriever) {
        try {
            retriever.release()
        } catch (e: Exception) {
            // Releasing is best-effort; a failure here must not
            // fail a call whose result is already computed.
        }
    }

    /** Duration in microseconds, or -1 when the metadata has
     * none (an unreadable video — Dart skips it). */
    private fun durationUs(assetId: String): Long {
        val retriever = openRetriever(assetId)
        try {
            val ms = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )?.toLongOrNull() ?: return -1L
            return if (ms > 0) ms * 1000L else -1L
        } finally {
            releaseQuietly(retriever)
        }
    }

    /** One 9x8 PNG (or null) per requested timestamp, in order. */
    private fun extractFrames(
        assetId: String,
        timestampsUs: List<Long>,
    ): List<ByteArray?> {
        val retriever = openRetriever(assetId)
        try {
            return timestampsUs.map { timeUs -> framePng(retriever, timeUs) }
        } finally {
            releaseQuietly(retriever)
        }
    }

    /** A single frame as PNG bytes, or null when this frame —
     * not the whole video — could not be read. */
    private fun framePng(retriever: MediaMetadataRetriever, timeUs: Long): ByteArray? {
        return try {
            val bitmap = scaledFrame(retriever, timeUs) ?: return null
            try {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                stream.toByteArray()
            } finally {
                bitmap.recycle()
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * The frame at [timeUs] at exactly 9x8 px. The platform's
     * scaled-frame call only exists from API 30; below that the
     * full frame is fetched and scaled down with the bitmap
     * scaler (bilinear) instead. Either way the raster that
     * reaches Dart is 9x8 — the downscale algorithm differs
     * slightly by API level, which is harmless: fingerprints
     * are only ever compared against fingerprints made by the
     * same device build (ADR-019's self-consistency rule).
     */
    private fun scaledFrame(
        retriever: MediaMetadataRetriever,
        timeUs: Long,
    ): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return retriever.getScaledFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                FRAME_WIDTH,
                FRAME_HEIGHT,
            )
        }
        val frame = retriever.getFrameAtTime(
            timeUs,
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
        ) ?: return null
        if (frame.width == FRAME_WIDTH && frame.height == FRAME_HEIGHT) {
            return frame
        }
        val scaled = Bitmap.createScaledBitmap(frame, FRAME_WIDTH, FRAME_HEIGHT, true)
        if (scaled !== frame) {
            frame.recycle()
        }
        return scaled
    }
}
