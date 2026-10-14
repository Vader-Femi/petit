package com.outsidetheide.petit

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Keeps Petit alive while it compresses in the background. The Dart
        // side is AndroidBackgroundKeepAlive.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEP_ALIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        CompressionService.begin(
                            applicationContext,
                            call.argument<String>("title") ?: "Compressing",
                            call.argument<String>("text") ?: ""
                        )
                        result.success(null)
                    }

                    "update" -> {
                        CompressionService.update(
                            call.argument<Int>("percent") ?: 0,
                            call.argument<String>("text") ?: ""
                        )
                        result.success(null)
                    }

                    "stop" -> {
                        CompressionService.end(applicationContext)
                        result.success(null)
                    }

                    "requestNotificationPermission" -> requestNotificationPermission(result)

                    else -> result.notImplemented()
                }
            }
    }

    /** Android 13+ asks before showing notifications; older versions never do. */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            // A question is already on screen.
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_REQUEST) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private companion object {
        const val KEEP_ALIVE_CHANNEL = "com.outsidetheide.petit/keep_alive"
        const val NOTIFICATION_REQUEST = 4712
    }
}
