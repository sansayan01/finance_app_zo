package com.example.finance

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.microflow.app_icon"

    // Map preset IDs to their activity-alias component names.
    // Each alias is declared in AndroidManifest.xml with its own icon + label.
    private val iconAliases = mapOf(
        "default" to ".MainActivityDefault",
        "bank_blue" to ".MainActivityBankBlue",
        "savings_green" to ".MainActivitySavingsGreen",
        "micro_orange" to ".MainActivityMicroOrange",
        "trust_purple" to ".MainActivityTrustPurple",
        "field_teal" to ".MainActivityFieldTeal",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
        // If none explicitly enabled, check if the real MainActivity is enabled
        // (which means "default" is active since it's the initial launcher)
        return "default"
    }

    private fun setIcon(presetId: String): Boolean {
        if (!iconAliases.containsKey(presetId)) return false

        val pm = packageManager

        // Disable all aliases first
        for ((_, aliasName) in iconAliases) {
            val component = ComponentName(packageName, "$packageName$aliasName")
            pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Also disable the real MainActivity launcher intent
        val mainComponent = ComponentName(packageName, "$packageName.MainActivity")
        pm.setComponentEnabledSetting(
            mainComponent,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )

        // Enable the selected alias
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
}
