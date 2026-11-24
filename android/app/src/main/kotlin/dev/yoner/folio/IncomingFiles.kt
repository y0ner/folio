package dev.yoner.folio

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Recibe archivos externos enviados a Folio mediante Intents VIEW o SEND
 * y los expone a Flutter por el canal `folio/incoming`.
 */
class IncomingFiles(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingInitialIntent: Intent? = activity.intent
    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getInitial") {
            val intent = pendingInitialIntent
            pendingInitialIntent = null
            val request = intent?.let(::extractRequest)
            if (request == null) {
                result.success(null)
                return
            }
            executor.execute {
                try {
                    val file = copyUriToCache(request.uri, request.mimeType)
                    val payload = mapOf("path" to file.absolutePath, "name" to file.name)
                    mainHandler.post {
                        if (!disposed) result.success(payload)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error al recibir archivo inicial", e)
                    val message = e.message ?: "No se pudo recibir el archivo"
                    mainHandler.post {
                        if (!disposed) result.error("incoming_error", message, null)
                    }
                }
            }
        } else {
            result.notImplemented()
        }
    }

    /** Procesa un nuevo Intent cuando la actividad ya está abierta (`singleTop`). */
    fun handleNewIntent(intent: Intent) {
        val request = extractRequest(intent) ?: return
        executor.execute {
            try {
                val file = copyUriToCache(request.uri, request.mimeType)
                val payload = mapOf("path" to file.absolutePath, "name" to file.name)
                mainHandler.post {
                    if (!disposed) channel.invokeMethod("onFile", payload)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error al recibir archivo", e)
                val message = e.message ?: "No se pudo recibir el archivo"
                mainHandler.post {
                    if (!disposed) {
                        channel.invokeMethod("onError", mapOf("message" to message))
                    }
                }
            }
        }
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private data class IncomingRequest(val uri: Uri, val mimeType: String?)

    private fun extractRequest(intent: Intent): IncomingRequest? {
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> getStreamUri(intent)
            else -> null
        }
        return uri?.let { IncomingRequest(it, intent.type) }
    }

    private fun getStreamUri(intent: Intent): Uri? {
        val extraStream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }
        if (extraStream != null) return extraStream
        val clip = intent.clipData
        return if (clip != null && clip.itemCount > 0) clip.getItemAt(0).uri else null
    }

    private fun copyUriToCache(uri: Uri, fallbackMime: String?): File {
        val resolver = activity.contentResolver
        var name = resolveDisplayName(resolver, uri)
        if (!hasExtension(name)) {
            val mime = resolver.getType(uri) ?: fallbackMime
            val ext = extensionForMime(mime)
            if (ext != null) {
                name = "$name.$ext"
            }
        }

        val incomingDir = File(activity.cacheDir, "incoming")
        if (!incomingDir.exists() && !incomingDir.mkdirs()) {
            throw IOException("No se pudo crear la carpeta temporal")
        }

        val destFile = File(incomingDir, name)
        val input = resolver.openInputStream(uri)
            ?: throw IOException("No se pudo abrir el flujo del archivo")

        try {
            input.use { src ->
                FileOutputStream(destFile).use { dst ->
                    src.copyTo(dst)
                }
            }
        } catch (e: Exception) {
            if (destFile.exists()) {
                destFile.delete()
            }
            throw e
        }
        return destFile
    }

    private fun resolveDisplayName(resolver: ContentResolver, uri: Uri): String {
        var rawName: String? = null
        if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
            try {
                resolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) {
                            rawName = cursor.getString(idx)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo consultar DISPLAY_NAME para $uri", e)
            }
        }

        if (rawName.isNullOrBlank()) {
            rawName = uri.lastPathSegment
        }

        val base = rawName?.let { File(it).name }?.replace('\u0000', '_')?.trim()
        return if (base.isNullOrBlank() || base == "." || base == "..") {
            "documento"
        } else {
            base
        }
    }

    private fun hasExtension(name: String): Boolean {
        val dot = name.lastIndexOf('.')
        return dot > 0 && dot < name.length - 1
    }

    private fun extensionForMime(mime: String?): String? {
        val normalized = mime?.substringBefore(';')?.trim()?.lowercase() ?: return null
        return when (normalized) {
            "application/pdf" -> "pdf"
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "docx"
            "application/vnd.ms-word.document.macroenabled.12" -> "docm"
            "application/vnd.openxmlformats-officedocument.wordprocessingml.template" -> "dotx"
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "xlsx"
            "application/vnd.ms-excel.sheet.macroenabled.12" -> "xlsm"
            "application/vnd.ms-excel" -> "xls"
            "text/csv", "text/comma-separated-values" -> "csv"
            "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "pptx"
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow" -> "ppsx"
            "application/vnd.ms-powerpoint.presentation.macroenabled.12" -> "pptm"
            else -> null
        }
    }

    companion object {
        private const val CHANNEL = "folio/incoming"
        private const val TAG = "Folio"
    }
}
