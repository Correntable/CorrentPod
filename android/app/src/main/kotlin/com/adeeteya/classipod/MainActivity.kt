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
                    val audioBytes = queryIndexedBytes(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Audio.Media.SIZE
                    )
                    val videoBytes = queryIndexedBytes(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Video.Media.SIZE
                    )
                    val photoBytes = queryIndexedBytes(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Images.Media.SIZE
                    )
                    result.success(
                        mapOf(
                            "totalBytes" to totalBytes,
                            "availableBytes" to availableBytes,
                            "audioBytes" to audioBytes,
                            "videoBytes" to videoBytes,
                            "photoBytes" to photoBytes
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

    private fun queryIndexedBytes(uri: android.net.Uri, sizeColumnName: String): Long {
        var total = 0L
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, arrayOf(sizeColumnName), null, null, null)
            val sizeColumn = cursor?.getColumnIndex(sizeColumnName) ?: -1
            if (cursor != null && sizeColumn >= 0) {
                while (cursor.moveToNext()) {
                    if (!cursor.isNull(sizeColumn)) {
                        total += cursor.getLong(sizeColumn).coerceAtLeast(0L)
                    }
                }
            }
        } catch (_: SecurityException) {
            // Android may restrict media visibility; device totals remain available.
        } finally {
            cursor?.close()
        }
        return total
    }
}
