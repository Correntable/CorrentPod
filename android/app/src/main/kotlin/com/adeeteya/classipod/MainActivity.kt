package com.adeeteya.classipod

import android.database.Cursor
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val storageChannel = "com.adeeteya.classipod/device_storage"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getStorageInfo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val storagePath = Environment.getExternalStorageDirectory().path
                    val stats = StatFs(storagePath)
                    val totalBytes = stats.totalBytes
                    val availableBytes = stats.availableBytes
                    val audioBytes = queryIndexedAudioBytes()
                    result.success(
                        mapOf(
                            "totalBytes" to totalBytes,
                            "availableBytes" to availableBytes,
                            "audioBytes" to audioBytes
                        )
                    )
                } catch (exception: Exception) {
                    result.error(
                        "storage_unavailable",
                        exception.localizedMessage ?: "Unable to read device storage.",
                        null
                    )
                }
            }
    }

    private fun queryIndexedAudioBytes(): Long {
        var total = 0L
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Audio.Media.SIZE),
                null,
                null,
                null
            )
            val sizeColumn = cursor?.getColumnIndex(MediaStore.Audio.Media.SIZE) ?: -1
            if (cursor != null && sizeColumn >= 0) {
                while (cursor.moveToNext()) {
                    if (!cursor.isNull(sizeColumn)) {
                        total += cursor.getLong(sizeColumn).coerceAtLeast(0L)
                    }
                }
            }
        } catch (_: SecurityException) {
            // Keep storage totals available even if media access is restricted.
        } finally {
            cursor?.close()
        }
        return total
    }
}
