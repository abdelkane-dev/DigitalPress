package com.digitalpress.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.digitalpress.app/security"

    // ─── ANTI-CAPTURE D'ÉCRAN GLOBALE ─────────────────────────────────────
    // FLAG_SECURE est appliqué à la fenêtre TOUTE LA DURÉE de l'app : les
    // captures d'écran et l'enregistrement d'écran sont bloqués partout
    // (fil, lecteur, comptes…), pas seulement pendant la lecture d'un
    // document (demande explicite : « rien ne sort de l'app, même les
    // captures d'écran sont bloquées »).
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    try {
                        if (enable) {
                            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SECURITY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
