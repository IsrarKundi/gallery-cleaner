package mobile.wipe.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Fix plan Stage 2 (ADR-017): wipe.'s own one-pass media
        // enumeration. Read-only MediaStore queries; see
        // MediaEnumerationChannel for the contract.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MediaEnumerationChannel.CHANNEL_NAME,
        ).setMethodCallHandler(MediaEnumerationChannel(contentResolver))
        // Fix plan Stage 6 (ADR-021): wipe.'s own video frame
        // grabber for the similar-videos check. Read-only frame
        // extraction at chosen timestamps; see VideoFrameChannel
        // for the contract.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VideoFrameChannel.CHANNEL_NAME,
        ).setMethodCallHandler(VideoFrameChannel(applicationContext))
    }
}
