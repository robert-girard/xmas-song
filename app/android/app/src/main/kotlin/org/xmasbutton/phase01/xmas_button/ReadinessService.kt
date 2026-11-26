package org.xmasbutton.phase01.xmas_button

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelUuid
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class ReadinessService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var scanner: android.bluetooth.le.BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null
    private var player: MediaPlayer? = null
    private var session = 0
    private var started = false
    private var prepared = false
    private var playbackActive = false
    private var foregroundPromoted = false
    private var activeAttemptId = INVALID_ATTEMPT_ID
    private var scanCallback: ScanCallback? = null
    private var timeout: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val attemptId = intent?.getLongExtra(EXTRA_ATTEMPT_ID, INVALID_ATTEMPT_ID)
            ?: INVALID_ATTEMPT_ID
        if (attemptId == INVALID_ATTEMPT_ID) {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }

        if (started) {
            if (activeAttemptId == attemptId && foregroundPromoted) {
                startAcknowledger?.invoke(attemptId, null)
            } else if (activeAttemptId != attemptId) {
                startAcknowledger?.invoke(attemptId, "Another readiness session is already active")
            }
            return START_NOT_STICKY
        }

        activeAttemptId = attemptId
        try {
            createNotificationChannel()
            promoteConnectedDevice()
            foregroundPromoted = true
            Log.i(TAG, "Foreground promotion succeeded")
            if (cancelledAttempts.remove(attemptId)) {
                Log.i(TAG, "Expired start promoted then stopped before scanning")
                disposeSession()
                state("Inactive", "Setup request expired")
                stopSelfResult(startId)
                return START_NOT_STICKY
            }

            started = true
            session++
            state("Starting", "Starting Bluetooth readiness service")
            startAcknowledger?.invoke(attemptId, null)
            scan()
        } catch (e: Exception) {
            Log.e(TAG, "Foreground promotion failed", e)
            startAcknowledger?.invoke(attemptId, e.message ?: "Foreground promotion failed")
            disposeSession()
            state("Error", "Could not start background readiness: ${e.message}")
            stopSelfResult(startId)
        }
        return START_NOT_STICKY
    }

    private fun promoteConnectedDevice() {
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification("Setting up button"),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification("Setting up button"))
        }
    }

    private fun scan() {
        if (checkSelfPermission(if (Build.VERSION.SDK_INT >= 31) Manifest.permission.BLUETOOTH_SCAN else Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            fail("Bluetooth permission was revoked before scanning")
            return
        }
        val manager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter = manager.adapter ?: run { fail("Bluetooth is unavailable"); return }
        if (!adapter.isEnabled) { fail("Turn on Bluetooth, then retry setup"); return }
        val bleScanner = adapter.bluetoothLeScanner ?: run { fail("BLE scanning is unavailable"); return }
        scanner = bleScanner
        state("Scanning", "Looking for Xmas Button")
        val scanSession = session
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (scanSession != session || gatt != null) return
                val ids = result.scanRecord?.serviceUuids?.map { it.uuid } ?: emptyList()
                if (SERVICE_UUID !in ids) return
                Log.i(TAG, "Matched advertisement name=${result.scanRecord?.deviceName ?: ""} service=$SERVICE_UUID")
                stopScan()
                connect(result.device, scanSession)
            }
            override fun onScanFailed(errorCode: Int) { if (scanSession == session) fail("BLE scan failed ($errorCode)") }
        }
        scanCallback = cb
        try {
            val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()
            val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).setLegacy(true).build()
            bleScanner.startScan(listOf(filter), settings, cb)
            armTimeout(scanSession, 15000, "Button not found before scan timeout")
        } catch (e: SecurityException) { fail("Bluetooth scan permission is missing") }
        catch (e: Exception) { fail("Could not start BLE scan: ${e.message}") }
    }

    private fun connect(device: BluetoothDevice, token: Int) {
        state("Connecting", "Connecting to Xmas Button")
        try {
            gatt = device.connectGatt(
                this,
                false,
                callback(token),
                BluetoothDevice.TRANSPORT_LE,
                BluetoothDevice.PHY_LE_1M_MASK,
                main,
            )
            if (gatt == null) { fail("Could not create BLE connection"); return }
            armTimeout(token, 15000, "BLE connection timed out")
        } catch (e: SecurityException) { fail("Bluetooth connect permission is missing") }
        catch (e: Exception) { fail("Could not connect: ${e.message}") }
    }

    private fun callback(token: Int) = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (!current(token, g)) return
            if (status != BluetoothGatt.GATT_SUCCESS) { fail("BLE connection failed ($status)"); return }
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                state("Discovering", "Checking button service")
                if (!g.discoverServices()) fail("Could not start service discovery")
                else armTimeout(token, 10000, "Service discovery timed out")
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) fail("Button disconnected")
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            if (!current(token, g)) return
            if (status != BluetoothGatt.GATT_SUCCESS) { fail("Service discovery failed ($status)"); return }
            val service = g.getService(SERVICE_UUID)
            val characteristic = service?.getCharacteristic(CHARACTERISTIC_UUID)
            if (characteristic == null || (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) == 0) {
                fail("Expected notify-only command characteristic was not found"); return
            }
            if (!g.setCharacteristicNotification(characteristic, true)) { fail("Could not enable local notification delivery"); return }
            val cccd = characteristic.getDescriptor(CCCD_UUID) ?: run { fail("Command CCCD is missing"); return }
            state("Subscribing", "Confirming button notifications")
            val accepted = if (Build.VERSION.SDK_INT >= 33) {
                g.writeDescriptor(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                g.writeDescriptor(cccd)
            }
            if (!accepted) { fail("Could not queue CCCD subscription"); return }
            armTimeout(token, 10000, "CCCD confirmation timed out")
        }

        override fun onDescriptorWrite(g: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (!current(token, g) || descriptor.uuid != CCCD_UUID || descriptor.characteristic.uuid != CHARACTERISTIC_UUID) return
            if (status != BluetoothGatt.GATT_SUCCESS) { fail("CCCD subscription failed ($status)"); return }
            clearTimeout()
            Log.i(TAG, "CCCD subscription succeeded")
            prepareAudio(token)
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (!current(token, g) || characteristic.uuid != CHARACTERISTIC_UUID) return
            handleCommand(characteristic.value?.clone() ?: byteArrayOf())
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            if (!current(token, g) || characteristic.uuid != CHARACTERISTIC_UUID) return
            handleCommand(value.clone())
        }
    }

    private fun handleCommand(value: ByteArray) {
        if (!prepared || value.size != 1 || value[0] != PLAY_PAUSE) return
        val p = player ?: return
        try {
            if (playbackActive) {
                p.pause()
                playbackActive = false
            } else {
                p.start()
                playbackActive = true
                promoteMediaPlayback()
            }
            Log.i(TAG, "Handled command 0x01")
            updateNotification(if (playbackActive) "Ready · Playing" else "Ready")
        } catch (e: Exception) { fail("Could not apply playback command: ${e.message}") }
    }

    private fun prepareAudio(token: Int) {
        state("Preparing", "Preparing offline track")
        try {
            val p = MediaPlayer()
            player = p
            p.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            p.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            p.setOnErrorListener { _, what, extra -> if (token == session) fail("Audio preparation failed ($what/$extra)"); true }
            p.setOnCompletionListener {
                if (token == session && p === player) {
                    playbackActive = false
                    updateNotification("Ready")
                }
            }
            p.setOnPreparedListener {
                if (token != session || p !== player) { p.release(); return@setOnPreparedListener }
                clearTimeout()
                prepared = true
                Log.i(TAG, "Audio prepared silently")
                updateNotification("Ready")
                state("Ready", "Button connected · track ready offline")
            }
            resources.openRawResourceFd(R.raw.track_01).use { fd -> p.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            p.prepareAsync()
            armTimeout(token, 15000, "Audio preparation timed out")
        } catch (e: Exception) { fail("Could not prepare bundled audio: ${e.message}") }
    }

    private fun promoteMediaPlayback() {
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification("Ready · Playing"),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        }
    }

    private fun armTimeout(token: Int, millis: Long, message: String) {
        clearTimeout()
        timeout = Runnable { if (token == session) fail(message) }.also { main.postDelayed(it, millis) }
    }
    private fun clearTimeout() { timeout?.let(main::removeCallbacks); timeout = null }
    private fun current(token: Int, g: BluetoothGatt) = token == session && g === gatt

    private fun stopScan() {
        val cb = scanCallback ?: return
        try { scanner?.stopScan(cb) } catch (_: SecurityException) { }
        scanCallback = null
        clearTimeout()
    }

    private fun fail(message: String) {
        if (!started) return
        Log.w(TAG, message)
        disposeSession()
        state("Error", message)
        stopSelf()
    }

    private fun disposeSession() {
        session++
        clearTimeout()
        stopScan()
        val old = gatt
        gatt = null
        try { old?.disconnect() } catch (_: SecurityException) { }
        try { old?.close() } catch (_: Exception) { }
        player?.let { try { it.release() } catch (_: Exception) { } }
        player = null
        prepared = false
        playbackActive = false
        if (foregroundPromoted) stopForeground(STOP_FOREGROUND_REMOVE)
        foregroundPromoted = false
        started = false
        activeAttemptId = INVALID_ATTEMPT_ID
    }

    private fun cancelAttempt(attemptId: Long) {
        if (activeAttemptId == attemptId) {
            disposeSession()
            state("Inactive", "Setup request expired")
            stopSelf()
        } else {
            cancelledAttempts.add(attemptId)
        }
    }

    override fun onDestroy() {
        val previousStatus = currentState["status"]
        disposeSession()
        if (previousStatus != "Error") state("Inactive", "Readiness service stopped")
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun state(status: String, detail: String) {
        currentState = mapOf("status" to status, "detail" to detail)
        observer?.invoke(currentState)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Button readiness", NotificationManager.IMPORTANCE_LOW))
        }
    }

    private fun notification(text: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = intent?.let { PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE) }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Xmas Button")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }

    private fun updateNotification(text: String) {
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, notification(text))
    }

    companion object {
        private const val TAG = "XmasReadiness"
        private const val CHANNEL_ID = "xmas_button_readiness"
        private const val NOTIFICATION_ID = 42
        private const val INVALID_ATTEMPT_ID = -1L
        const val EXTRA_ATTEMPT_ID = "org.xmasbutton.phase01.extra.ATTEMPT_ID"
        const val ACTION_START = "org.xmasbutton.phase01.action.START"
        private const val PLAY_PAUSE = 0x01.toByte()
        private val SERVICE_UUID = UUID.fromString("55f93b80-da2b-42f4-bad6-a4ec40e3ea7c")
        private val CHARACTERISTIC_UUID = UUID.fromString("2206a557-99b7-4176-98f4-d066c053335e")
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        @Volatile private var currentState: Map<String, String> = mapOf("status" to "Inactive", "detail" to "Tap Set up button to begin")
        @Volatile var observer: ((Map<String, String>) -> Unit)? = null
        @Volatile var startAcknowledger: ((Long, String?) -> Unit)? = null
        @Volatile private var instance: ReadinessService? = null
        private val cancelledAttempts = ConcurrentHashMap.newKeySet<Long>()
        fun snapshot() = currentState
        fun isStartingOrReady() = currentState["status"] in setOf("Starting", "Scanning", "Connecting", "Discovering", "Subscribing", "Preparing", "Ready")
        fun cancelStartAttempt(attemptId: Long) {
            val service = instance
            if (service != null && service.activeAttemptId == attemptId) {
                if (Looper.myLooper() == service.main.looper) service.cancelAttempt(attemptId)
                else service.main.post { service.cancelAttempt(attemptId) }
            } else {
                cancelledAttempts.add(attemptId)
            }
        }
    }
}
