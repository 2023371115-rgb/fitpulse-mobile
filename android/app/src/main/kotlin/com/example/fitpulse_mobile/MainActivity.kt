package com.example.fitpulse_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Canal que usa lib/services/home_widget_service.dart para actualizar el widget.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitpulse/widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    FitPulseWidget.save(applicationContext, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                    result.success(true)
                }
                "clear" -> {
                    FitPulseWidget.clear(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
