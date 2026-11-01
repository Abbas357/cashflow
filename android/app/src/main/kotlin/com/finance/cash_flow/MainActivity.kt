package com.finance.cash_flow

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    /** Tells the app which country the phone is in. None of this needs a permission. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.finance.cash_flow/region")
            .setMethodCallHandler { call, result ->
                if (call.method != "hints") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                result.success(
                    mapOf(
                        "sim" to phone?.simCountryIso,
                        "network" to phone?.networkCountryIso,
                        "zone" to TimeZone.getDefault().id,
                    ),
                )
            }
    }
}
