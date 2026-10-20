package com.example.birdshop_posapp

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class ThermalPrinterChannel(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "exsha/thermal_printer")
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private val prefs = activity.getSharedPreferences("thermal_printer", 0)
    private val adapter get() = activity.getSystemService(BluetoothManager::class.java)?.adapter
    @Volatile private var socket: BluetoothSocket? = null
    private var permissionResult: MethodChannel.Result? = null
    private var permissionAction: (() -> Unit)? = null
    private val disconnectReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            @Suppress("DEPRECATION")
            val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            if (intent.action == BluetoothAdapter.ACTION_STATE_CHANGED ||
                (permitted() && device?.address == socket?.remoteDevice?.address)) {
                if (intent.action != BluetoothAdapter.ACTION_STATE_CHANGED ||
                    intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) != BluetoothAdapter.STATE_ON) closeSocket()
                publishStatus()
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        val filter = IntentFilter(BluetoothDevice.ACTION_ACL_DISCONNECTED).apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(disconnectReceiver, filter, Context.RECEIVER_EXPORTED)
        else @Suppress("DEPRECATION") activity.registerReceiver(disconnectReceiver, filter)
    }

    fun publishStatus() { channel.invokeMethod("statusChanged", status()) }

    private fun permitted() = Build.VERSION.SDK_INT < 31 ||
        activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun status(): Map<String, Any?> {
        val allowed = permitted()
        val bt = adapter
        return mapOf(
            "supported" to (bt != null), "permission" to allowed,
            "enabled" to (allowed && bt?.isEnabled == true),
            "connected" to (allowed && bt?.isEnabled == true && socket?.isConnected == true),
            "address" to prefs.getString("address", null),
            "name" to prefs.getString("name", null),
            "paperMm" to prefs.getInt("paperMm", 58)
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "devices" -> withPermission(result) {
                try {
                    val bt = available()
                    result.success(bt.bondedDevices.filter { it.type != BluetoothDevice.DEVICE_TYPE_LE }
                        .sortedBy { it.name ?: it.address }.map { mapOf("name" to (it.name ?: "Printer Bluetooth"), "address" to it.address) })
                } catch (e: Exception) { failure(result, e) }
            }
            "connect" -> withPermission(result) {
                val address = call.argument<String>("address")
                if (address == null || !BluetoothAdapter.checkBluetoothAddress(address)) {
                    result.error("invalid_device", "Alamat printer tidak valid.", null)
                } else io(result, 15000) {
                    val bt = available()
                    val device = bt.bondedDevices.firstOrNull { it.address == address }
                        ?: throw IllegalStateException("Pasangkan printer terlebih dahulu di pengaturan Bluetooth Android.")
                    closeSocket()
                    val connection = device.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
                    socket = connection
                    connection.connect()
                    prefs.edit().putString("address", address).putString("name", device.name ?: "Printer Bluetooth").apply()
                    status()
                }
            }
            "write" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_data", "Data struk kosong.", null)
                } else io(result, 60000) {
                    available()
                    val connection = socket?.takeIf { it.isConnected }
                        ?: throw IllegalStateException("Printer terputus. Hubungkan kembali sebelum mencetak.")
                    val output = connection.outputStream
                    var offset = 0
                    handler.post { channel.invokeMethod("writeProgress", mapOf("sent" to 0, "total" to bytes.size)) }
                    while (offset < bytes.size) {
                        val count = minOf(512, bytes.size - offset)
                        output.write(bytes, offset, count)
                        offset += count
                        val sent = offset
                        handler.post { channel.invokeMethod("writeProgress", mapOf("sent" to sent, "total" to bytes.size)) }
                        // Pace small printer buffers; validate throughput on the actual printer.
                        Thread.sleep(20)
                    }
                    output.flush()
                    null
                }
            }
            "disconnect" -> {
                if (busy.get()) result.error("busy", "Tunggu proses printer selesai.", null)
                else { closeSocket(); result.success(status()) }
            }
            "paper" -> {
                val width = call.argument<Int>("paperMm") ?: 0
                if (busy.get()) result.error("busy", "Tunggu proses printer selesai.", null)
                else if (width != 58 && width != 80) result.error("invalid_paper", "Pilih kertas 58 mm atau 80 mm.", null)
                else { prefs.edit().putInt("paperMm", width).apply(); result.success(status()) }
            }
            "bluetoothSettings", "appSettings" -> {
                val intent = if (call.method == "appSettings") Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                    else Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                try { activity.startActivity(intent); result.success(null) }
                catch (e: Exception) { failure(result, e) }
            }
            else -> result.notImplemented()
        }
    }

    private fun available(): BluetoothAdapter {
        if (!permitted()) throw SecurityException("Izinkan Perangkat di sekitar pada pengaturan izin aplikasi.")
        val bt = adapter ?: throw IllegalStateException("Perangkat ini tidak mendukung Bluetooth Classic.")
        check(bt.isEnabled) { "Bluetooth nonaktif. Aktifkan Bluetooth di pengaturan Android." }
        return bt
    }

    private fun withPermission(result: MethodChannel.Result, action: () -> Unit) {
        if (permitted()) { action(); return }
        if (permissionResult != null) { result.error("busy", "Selesaikan permintaan izin Bluetooth.", null); return }
        permissionResult = result
        permissionAction = action
        activity.requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 5801)
    }

    fun onPermissionResult(requestCode: Int, grants: IntArray) {
        if (requestCode != 5801) return
        val result = permissionResult
        val action = permissionAction
        permissionResult = null
        permissionAction = null
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED) action?.invoke()
        else result?.error("permission_denied", "Izin Bluetooth ditolak. Izinkan Perangkat di sekitar pada pengaturan izin aplikasi.", null)
    }

    private fun io(result: MethodChannel.Result, timeoutMs: Long, action: () -> Any?) {
        if (!busy.compareAndSet(false, true)) { result.error("busy", "Tunggu proses printer selesai.", null); return }
        val expired = AtomicBoolean(false)
        val timeout = Runnable { expired.set(true); closeSocket() }
        handler.postDelayed(timeout, timeoutMs)
        worker.execute {
            try {
                val value = action()
                handler.post {
                    handler.removeCallbacks(timeout)
                    busy.set(false)
                    if (expired.get()) result.error("timeout", "Printer tidak merespons. Periksa daya dan jarak printer.", null)
                    else result.success(value)
                }
            } catch (e: Exception) {
                closeSocket()
                handler.post {
                    handler.removeCallbacks(timeout)
                    busy.set(false)
                    if (expired.get()) result.error("timeout", "Printer tidak merespons. Periksa daya dan jarak printer.", null)
                    else failure(result, e)
                }
            }
        }
    }

    private fun failure(result: MethodChannel.Result, e: Exception) {
        val message = when (e) {
            is SecurityException -> "Izinkan Perangkat di sekitar pada pengaturan izin aplikasi."
            is IOException -> "Koneksi printer gagal. Periksa daya, jarak, dan pastikan printer tidak dipakai aplikasi lain."
            else -> e.message ?: "Printer tidak tersedia. Periksa pengaturan Bluetooth."
        }
        result.error("printer_error", message, null)
    }

    private fun closeSocket() {
        val old = socket
        socket = null
        try { old?.close() } catch (_: IOException) { }
    }

    fun dispose() {
        activity.unregisterReceiver(disconnectReceiver)
        channel.setMethodCallHandler(null)
        permissionResult?.error("cancelled", "Permintaan printer dibatalkan.", null)
        permissionResult = null
        permissionAction = null
        closeSocket()
        worker.shutdownNow()
    }
}
