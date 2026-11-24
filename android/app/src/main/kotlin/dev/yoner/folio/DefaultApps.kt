package dev.yoner.folio

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Consulta la aplicación predeterminada para cada tipo de documento y permite
 * abrir el selector del sistema o los ajustes de la app actual por `folio/defaults`.
 */
class DefaultApps(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> handleStatus(result)
            "choose" -> handleChoose(call, result)
            "openAppSettings" -> handleOpenAppSettings(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleStatus(result: MethodChannel.Result) {
        executor.execute {
            try {
                val items = SAMPLES.map { spec ->
                    val uri = ensureSampleUri(spec)
                    resolveDefault(spec, uri)
                }
                mainHandler.post {
                    if (!disposed) result.success(items)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error al consultar apps predeterminadas", e)
                val message = e.message ?: "No se pudo consultar las apps predeterminadas"
                mainHandler.post {
                    if (!disposed) result.error("status_error", message, null)
                }
            }
        }
    }

    private fun handleChoose(call: MethodCall, result: MethodChannel.Result) {
        val kind = call.argument<String>("kind")
        val spec = SAMPLES.firstOrNull { it.kind == kind }
        if (spec == null) {
            result.error("invalid_args", "Tipo de documento no válido", null)
            return
        }
        executor.execute {
            try {
                val uri = ensureSampleUri(spec)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, spec.mimeType)
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_ACTIVITY_NEW_TASK,
                    )
                }
                mainHandler.post {
                    if (disposed) return@post
                    try {
                        activity.startActivity(intent)
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        Log.w(TAG, "No hay app disponible para ${spec.kind}", e)
                        result.error(
                            "no_app",
                            "No hay ninguna aplicación disponible para este tipo",
                            null,
                        )
                    } catch (e: Exception) {
                        Log.w(TAG, "Error al abrir selector para ${spec.kind}", e)
                        result.error(
                            "choose_error",
                            e.message ?: "No se pudo abrir el selector",
                            null,
                        )
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error preparando la muestra para ${spec.kind}", e)
                val message = e.message ?: "No se pudo preparar la muestra"
                mainHandler.post {
                    if (!disposed) result.error("choose_error", message, null)
                }
            }
        }
    }

    private fun handleOpenAppSettings(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package")?.trim()
        if (packageName.isNullOrEmpty()) {
            result.error("invalid_args", "Nombre de paquete no válido", null)
            return
        }
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "No se pudieron abrir los ajustes de $packageName", e)
            result.error("settings_unavailable", "No se pudieron abrir los ajustes", null)
        } catch (e: Exception) {
            Log.w(TAG, "Error abriendo ajustes de $packageName", e)
            result.error(
                "settings_error",
                e.message ?: "No se pudieron abrir los ajustes",
                null,
            )
        }
    }

    private fun ensureSampleUri(spec: SampleSpec): Uri {
        val dir = File(activity.cacheDir, "muestras")
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("No se pudo crear la carpeta de muestras")
        }
        val destFile = File(dir, spec.assetName)
        if (!destFile.exists() || destFile.length() == 0L) {
            val assetKey = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset("assets/samples/${spec.assetName}")
            try {
                activity.assets.open(assetKey).use { src ->
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
        }
        return FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.muestras",
            destFile,
        )
    }

    private fun resolveDefault(spec: SampleSpec, uri: Uri): Map<String, String> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, spec.mimeType)
        val info: ResolveInfo? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        val act = info?.activityInfo
        if (act == null || isSystemResolver(info)) {
            return mapOf(
                "kind" to spec.kind,
                "state" to "none",
            )
        }
        val pkg = act.packageName
        if (pkg == activity.packageName) {
            return mapOf(
                "kind" to spec.kind,
                "state" to "folio",
            )
        }
        val rawLabel = info.loadLabel(pm).toString().trim()
        val appName = rawLabel.ifEmpty { pkg }
        return mapOf(
            "kind" to spec.kind,
            "state" to "other",
            "appName" to appName,
            "package" to pkg,
        )
    }

    private fun isSystemResolver(info: ResolveInfo): Boolean {
        val act = info.activityInfo ?: return true
        val pkg = act.packageName ?: return true
        val name = act.name ?: ""
        if (pkg == "android" ||
            pkg == "com.android.intentresolver" ||
            pkg == "com.google.android.intentresolver"
        ) {
            return true
        }
        if (name.contains("ResolverActivity", ignoreCase = true) ||
            name.contains("ChooserActivity", ignoreCase = true)
        ) {
            return true
        }
        return info.match == 0
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private data class SampleSpec(
        val kind: String,
        val mimeType: String,
        val assetName: String,
    )

    companion object {
        private const val CHANNEL = "folio/defaults"
        private const val TAG = "FolioDefaults"

        private val SAMPLES = listOf(
            SampleSpec(
                kind = "pdf",
                mimeType = "application/pdf",
                assetName = "folio-muestra.pdf",
            ),
            SampleSpec(
                kind = "word",
                mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                assetName = "folio-muestra.docx",
            ),
            SampleSpec(
                kind = "excel",
                mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                assetName = "folio-muestra.xlsx",
            ),
            SampleSpec(
                kind = "powerpoint",
                mimeType = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                assetName = "folio-muestra.pptx",
            ),
        )
    }
}
