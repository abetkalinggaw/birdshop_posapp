package com.example.birdshop_posapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var printer: ThermalPrinterChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        printer = ThermalPrinterChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        printer?.onPermissionResult(requestCode, grantResults)
    }

    override fun onResume() {
        super.onResume()
        printer?.publishStatus()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        printer?.dispose()
        printer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
