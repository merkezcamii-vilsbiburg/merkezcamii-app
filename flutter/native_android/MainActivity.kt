package de.merkezcamii.merkezcamii

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "merkezcamii/ezan").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        EzanAlarm.replaceAll(this, call.argument<String>("json") ?: "[]")
                        result.success(true)
                    }
                    "test" -> {
                        EzanService.start(this, "Ezan (deneme)", "Sessiz modda ezan böyle okunur", false)
                        result.success(true)
                    }
                    "stop" -> {
                        EzanService.stop(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ezan", e.message, null)
            }
        }
    }
}
