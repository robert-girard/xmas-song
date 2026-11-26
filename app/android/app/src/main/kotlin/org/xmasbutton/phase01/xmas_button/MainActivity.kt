package org.xmasbutton.phase01.xmas_button

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private var pendingStart: PendingStart? = null
    private val main = Handler(Looper.getMainLooper())
    private var resumed = false

    private data class PendingStart(val id: Long, val result: MethodChannel.Result)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "environment" -> result.success(environment())
                "start" -> startReadiness(result)
                "snapshot" -> result.success(ReadinessService.snapshot())
                "openLocationSettings" -> {
                    startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        ReadinessService.observer = { state -> main.post { channel.invokeMethod("stateChanged", state) } }
        ReadinessService.startAcknowledger = { attemptId, error -> main.post {
            val request = pendingStart?.takeIf { it.id == attemptId } ?: return@post
            main.removeCallbacksAndMessages(request)
            pendingStart = null
            if (error == null) request.result.success(ReadinessService.snapshot())
            else request.result.error("service_start_failed", error, null)
        } }
    }

    override fun onResume() {
        super.onResume()
        resumed = true
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    private fun environment(): Map<String, Any> {
        val locationOn = if (Build.VERSION.SDK_INT <= 30) {
            val manager = getSystemService(LOCATION_SERVICE) as LocationManager
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) || manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } else true
        return mapOf("apiLevel" to Build.VERSION.SDK_INT, "locationServicesEnabled" to locationOn)
    }

    private fun startReadiness(result: MethodChannel.Result) {
        if (!resumed) {
            result.error("activity_not_resumed", "Return to the app before starting button setup.", null)
            return
        }
        if (pendingStart != null) {
            result.error("start_in_progress", "Button setup is already starting.", null)
            return
        }
        if (ReadinessService.isStartingOrReady()) {
            result.success(ReadinessService.snapshot())
            return
        }
        val hasPermission = if (Build.VERSION.SDK_INT >= 31) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            result.error("permission_required", "Grant the required Bluetooth permission before setup.", null)
            return
        }
        if (Build.VERSION.SDK_INT <= 30 && !(environment()["locationServicesEnabled"] as Boolean)) {
            result.error("location_services_off", "Enable Location services for Android BLE scanning, then retry.", Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            return
        }
        val attemptId = nextAttemptId.incrementAndGet()
        val request = PendingStart(attemptId, result)
        val timeout = Runnable {
            if (pendingStart?.id != attemptId) return@Runnable
            pendingStart = null
            ReadinessService.cancelStartAttempt(attemptId)
            result.error("service_timeout", "The readiness service did not confirm foreground startup.", null)
        }
        pendingStart = request
        main.postAtTime(timeout, request, android.os.SystemClock.uptimeMillis() + START_TIMEOUT_MS)
        try {
            val intent = Intent(this, ReadinessService::class.java)
                .setAction(ReadinessService.ACTION_START)
                .putExtra(ReadinessService.EXTRA_ATTEMPT_ID, attemptId)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
        } catch (e: Exception) {
            main.removeCallbacksAndMessages(request)
            pendingStart = null
            ReadinessService.cancelStartAttempt(attemptId)
            result.error("service_start_failed", e.message ?: "Could not start readiness service.", null)
        }
    }

    override fun onDestroy() {
        pendingStart?.let { request ->
            main.removeCallbacksAndMessages(request)
            ReadinessService.cancelStartAttempt(request.id)
            request.result.error("activity_closed", "App closed before setup could start.", null)
            pendingStart = null
        }
        ReadinessService.observer = null
        ReadinessService.startAcknowledger = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "xmas_button/readiness"
        private const val START_TIMEOUT_MS = 5000L
        private val nextAttemptId = AtomicLong(android.os.SystemClock.elapsedRealtime())
    }
}
