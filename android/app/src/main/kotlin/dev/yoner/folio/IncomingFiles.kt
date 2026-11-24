package dev.yoner.folio

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
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
 * Recibe archivos externos enviados a Folio mediante Intents VIEW/SEND o el
 * selector nativo `ACTION_OPEN_DOCUMENT`, y los expone a Flutter por `folio/incoming`.
 */
class IncomingFiles(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingInitialIntent: Intent? = activity.intent
    private var pendingPickResult: MethodChannel.Result? = null
    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitial" -> handleGetInitial(result)
            "pick" -> handlePick(result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetInitial(result: MethodChannel.Result) {
        val intent = pendingInitialIntent
        pendingInitialIntent = null
        val request = intent?.let(::extractRequest)
        if (request == null) {
            result.success(null)
            return
        }
        if (isSampleUri(request.uri)) {
            val kind = sampleKind(request.uri, request.mimeType)
            if (kind != null) {
                result.success(mapOf("defaultChosen" to kind))
            } else {
                Log.w(TAG, "Muestra no reconocida en Intent inicial: ${request.uri}")
                result.error("incoming_error", "No se pudo identificar el tipo de muestra", null)
            }
            return
        }
        executor.execute {
            try {
                val file = copyUriToCache(request.uri, request.mimeType)
                val payload = buildPayload(file, request.uri)
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
    }

    private fun handlePick(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "Ya hay un selector de archivos abierto", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, PICK_MIME_TYPES)
        }
        pendingPickResult = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK_DOCUMENT)
        } catch (e: Exception) {
            pendingPickResult = null
            Log.w(TAG, "Error al abrir el selector de archivos", e)
            result.error("pick_error", e.message ?: "No se pudo abrir el selector", null)
        }
    }

    /** Procesa el resultado de `ACTION_OPEN_DOCUMENT` iniciado por `pick`. */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_DOCUMENT) return false
        val result = pendingPickResult ?: return true
        pendingPickResult = null

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            return true
        }

        val mimeType = data?.type
        executor.execute {
            try {
                val file = copyUriToCache(uri, mimeType)
                val payload = buildPayload(file, uri)
                mainHandler.post {
                    if (!disposed) result.success(payload)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error al abrir el archivo seleccionado", e)
                val message = e.message ?: "No se pudo recibir el archivo"
                mainHandler.post {
                    if (!disposed) result.error("pick_error", message, null)
                }
            }
        }
        return true
    }

    /** Procesa un nuevo Intent cuando la actividad ya está abierta (`singleTop`). */
    fun handleNewIntent(intent: Intent) {
        val request = extractRequest(intent) ?: return
        if (isSampleUri(request.uri)) {
            val kind = sampleKind(request.uri, request.mimeType)
            if (kind != null) {
                mainHandler.post {
                    if (!disposed) {
                        channel.invokeMethod("onDefaultChosen", mapOf("kind" to kind))
                    }
                }
            } else {
                Log.w(TAG, "Muestra no reconocida en onNewIntent: ${request.uri}")
            }
            return
        }
        executor.execute {
            try {
                val file = copyUriToCache(request.uri, request.mimeType)
                val payload = buildPayload(file, request.uri)
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
        pendingPickResult = null
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private fun isSampleUri(uri: Uri): Boolean =
        uri.scheme == ContentResolver.SCHEME_CONTENT &&
            uri.authority == "${activity.packageName}.muestras"

    private fun sampleKind(uri: Uri, fallbackMime: String?): String? {
        val ext = uri.lastPathSegment
            ?.substringAfterLast('.', "")
            ?.lowercase()
            ?.takeIf { it.isNotEmpty() }
            ?: extensionForMime(activity.contentResolver.getType(uri) ?: fallbackMime)
        return when (ext) {
            "pdf" -> "pdf"
            "docx", "docm", "dotx" -> "word"
            "xlsx", "xlsm", "xls", "csv" -> "excel"
            "pptx", "ppsx", "pptm" -> "powerpoint"
            else -> null
        }
    }

    private data class IncomingRequest(val uri: Uri, val mimeType: String?)

    private fun buildPayload(file: File, uri: Uri): Map<String, String> = mapOf(
        "path" to file.absolutePath,
        "name" to file.name,
        "uri" to resolveDisplayUri(uri),
    )

    /**
     * Deduce una URI `file://<ruta absoluta>` cuando es posible reconstruir la
     * ubicación real del archivo; si no, conserva `uri.toString()`.
     */
    private fun resolveDisplayUri(uri: Uri): String {
        val original = uri.toString()
        try {
            if (uri.scheme == ContentResolver.SCHEME_FILE) {
                val path = uri.path
                return if (!path.isNullOrBlank() && path.startsWith("/")) {
                    toFileUri(path)
                } else {
                    original
                }
            }

            if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
                return original
            }

            val authority = uri.authority?.lowercase() ?: return original
            val resolvedPath: String? = when (authority) {
                AUTHORITY_EXTERNAL_STORAGE -> resolveExternalStoragePath(uri)
                AUTHORITY_DOWNLOADS -> resolveDownloadsPath(uri)
                AUTHORITY_MEDIA -> resolveMediaDocumentsPath(uri)
                else -> null
            }

            return if (!resolvedPath.isNullOrBlank() && resolvedPath.startsWith("/")) {
                toFileUri(resolvedPath)
            } else {
                original
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error al resolver la ubicación real de $uri", e)
            return original
        }
    }

    private fun toFileUri(path: String): String = Uri.fromFile(File(path)).toString()

    private fun extractDocumentId(uri: Uri): String? {
        if (!DocumentsContract.isDocumentUri(activity, uri)) return null
        return try {
            DocumentsContract.getDocumentId(uri)
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo leer documentId de $uri", e)
            null
        }
    }

    private fun resolveExternalStoragePath(uri: Uri): String? {
        val docId = extractDocumentId(uri) ?: return null
        val colon = docId.indexOf(':')
        if (colon <= 0) return null
        val volume = docId.substring(0, colon)
        val rel = docId.substring(colon + 1).trimStart('/')
        val root = if (volume.equals("primary", ignoreCase = true)) {
            PRIMARY_STORAGE_ROOT
        } else {
            "/storage/$volume"
        }
        return if (rel.isEmpty()) root else "$root/$rel"
    }

    private fun resolveDownloadsPath(uri: Uri): String? {
        val docId = extractDocumentId(uri) ?: return null
        if (docId.startsWith("raw:")) {
            val rawPath = docId.removePrefix("raw:")
            return if (rawPath.startsWith("/")) rawPath else null
        }

        val mediaId = when {
            docId.startsWith("msf:") -> docId.removePrefix("msf:")
            docId.toLongOrNull() != null -> docId
            else -> null
        }
        if (mediaId.isNullOrBlank()) {
            Log.w(TAG, "Formato de documentId no reconocido en descargas: $docId")
            return null
        }

        val resolver = activity.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            queryMediaStorePath(resolver, MediaStore.Downloads.EXTERNAL_CONTENT_URI, mediaId)
                ?.let { return it }
        }
        val filesPath = queryMediaStorePath(
            resolver,
            MediaStore.Files.getContentUri("external"),
            mediaId,
        )
        if (filesPath == null) {
            Log.w(TAG, "Cursor vacío en MediaStore para descarga $uri")
        }
        return filesPath
    }

    private fun resolveMediaDocumentsPath(uri: Uri): String? {
        val docId = extractDocumentId(uri) ?: return null
        val colon = docId.indexOf(':')
        if (colon <= 0 || colon >= docId.length - 1) {
            Log.w(TAG, "Formato de documentId no reconocido en media: $docId")
            return null
        }
        val mediaId = docId.substring(colon + 1)
        val filesPath = queryMediaStorePath(
            activity.contentResolver,
            MediaStore.Files.getContentUri("external"),
            mediaId,
        )
        if (filesPath == null) {
            Log.w(TAG, "Cursor vacío en MediaStore para media $uri")
        }
        return filesPath
    }

    private fun queryMediaStorePath(
        resolver: ContentResolver,
        collectionUri: Uri,
        id: String,
    ): String? {
        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                MediaStore.MediaColumns.RELATIVE_PATH,
                MediaStore.MediaColumns.DISPLAY_NAME,
            )
        } else {
            @Suppress("DEPRECATION")
            arrayOf(MediaStore.MediaColumns.DATA)
        }
        val selection = "${MediaStore.MediaColumns._ID} = ?"
        val selectionArgs = arrayOf(id)

        return try {
            resolver.query(collectionUri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val relIdx = cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                    val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    val rel = if (relIdx >= 0) cursor.getString(relIdx) else null
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) else null
                    if (rel == null || name.isNullOrBlank()) {
                        return@use null
                    }
                    val cleanRel = rel.trim('/')
                    if (cleanRel.isEmpty()) {
                        "$PRIMARY_STORAGE_ROOT/$name"
                    } else {
                        "$PRIMARY_STORAGE_ROOT/$cleanRel/$name"
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    val data = if (dataIdx >= 0) cursor.getString(dataIdx) else null
                    if (!data.isNullOrBlank() && data.startsWith("/")) data else null
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error consultando MediaStore ($collectionUri) para id=$id", e)
            null
        }
    }

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
            "text/csv", "text/comma-separated-values", "application/csv" -> "csv"
            "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "pptx"
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow" -> "ppsx"
            "application/vnd.ms-powerpoint.presentation.macroenabled.12" -> "pptm"
            else -> null
        }
    }

    companion object {
        private const val CHANNEL = "folio/incoming"
        private const val TAG = "Folio"
        private const val REQUEST_PICK_DOCUMENT = 4102
        private const val PRIMARY_STORAGE_ROOT = "/storage/emulated/0"
        private const val AUTHORITY_EXTERNAL_STORAGE = "com.android.externalstorage.documents"
        private const val AUTHORITY_DOWNLOADS = "com.android.providers.downloads.documents"
        private const val AUTHORITY_MEDIA = "com.android.providers.media.documents"

        private val PICK_MIME_TYPES = arrayOf(
            "application/pdf",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-word.document.macroenabled.12",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.template",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel.sheet.macroenabled.12",
            "application/vnd.ms-excel",
            "text/csv",
            "text/comma-separated-values",
            "application/csv",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow",
            "application/vnd.ms-powerpoint.presentation.macroenabled.12",
        )
    }
}
