package dev.yoner.folio

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var incomingFiles: IncomingFiles? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        incomingFiles?.dispose()
        incomingFiles = IncomingFiles(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incomingFiles?.handleNewIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (incomingFiles?.handleActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        incomingFiles?.dispose()
        incomingFiles = null
        super.onDestroy()
    }
}
