package com.example.finance

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    private val ICON_CHANNEL = "com.microflow.app_icon"
    private val SMS_CHANNEL = "com.microflow/sms"
    private var smsPlugin: SmsSenderPlugin? = null

    // Map preset IDs to their activity-alias component names.
    // Each alias is declared in AndroidManifest.xml with its own icon + label.
    private val iconAliases = mapOf(
        "default" to ".MainActivityDefault",
        "bank_blue" to ".MainActivityBankBlue",
        "savings_green" to ".MainActivitySavingsGreen",
        "micro_orange" to ".MainActivityMicroOrange",
        "trust_purple" to ".MainActivityTrustPurple",
        "field_teal" to ".MainActivityFieldTeal",
        "future_swarupnagar" to ".MainActivityFutureSwarupnagar",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // SMS Sender plugin
        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsPlugin = SmsSenderPlugin(this, smsChannel)
        smsChannel.setMethodCallHandler(smsPlugin)

        // App icon channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "getCurrentIcon" -> result.success(getCurrentIcon())
                    "setIcon" -> {
                        val iconName = call.argument<String>("iconName")
                        if (iconName == null) {
                            result.error("INVALID_ARG", "iconName is required", null)
                        } else {
                            val success = setIcon(iconName)
                            result.success(success)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getCurrentIcon(): String {
        val pm = packageManager
        for ((presetId, aliasName) in iconAliases) {
            val component = ComponentName(packageName, "$packageName$aliasName")
            val state = pm.getComponentEnabledSetting(component)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return presetId
            }
        }
        return "default"
    }

    private fun setIcon(presetId: String): Boolean {
        if (!iconAliases.containsKey(presetId)) return false

        val pm = packageManager

        for ((_, aliasName) in iconAliases) {
            val component = ComponentName(packageName, "$packageName$aliasName")
            pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        val mainComponent = ComponentName(packageName, "$packageName.MainActivity")
        pm.setComponentEnabledSetting(
            mainComponent,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )

        val targetAlias = iconAliases[presetId]!!
        val targetComponent = ComponentName(packageName, "$packageName$targetAlias")
        pm.setComponentEnabledSetting(
            targetComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        return true
    }

    override fun onResume() {
        super.onResume()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsPlugin?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
