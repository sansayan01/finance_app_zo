package com.microflow.pro

import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.time.LocalTime
import java.util.concurrent.TimeUnit

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
        smsPlugin = SmsSenderPlugin(applicationContext, smsChannel, this)
        smsChannel.setMethodCallHandler(smsPlugin)

        // SMS scheduler channel (delegates to SmsReminderWorker via WorkManager)
        val schedulerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.microflow/sms_scheduler")
        schedulerChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enqueue_reminder_worker" -> {
                    val timeArg = call.argument<String>("time")
                    val timeStr = timeArg
                        ?: SmsBootReceiver.readStoredReminderTime(applicationContext)
                        ?: "08:00"
                    SmsBootReceiver.writeStoredReminderTime(applicationContext, timeStr)
                    val data = Data.Builder()
                        .putString(SmsReminderWorker.KEY_TIME, timeStr)
                        .build()
                    WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                        SmsReminderWorker.UNIQUE_NAME,
                        ExistingPeriodicWorkPolicy.KEEP,
                        PeriodicWorkRequestBuilder<SmsReminderWorker>(1, TimeUnit.DAYS)
                            .setInputData(data)
                            .build()
                    )
                    result.success(true)
                }
                "cancel_reminder_worker" -> {
                    WorkManager.getInstance(this).cancelUniqueWork(SmsReminderWorker.UNIQUE_NAME)
                    result.success(true)
                }
                "run_reminder_pass" -> {
                    result.success(0)
                }
                else -> result.notImplemented()
            }
        }

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

        // Disable every brand alias first.
        for ((_, aliasName) in iconAliases) {
            val component = ComponentName(packageName, "$packageName$aliasName")
            pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Enable the chosen alias.
        val targetAlias = iconAliases[presetId]!!
        val targetComponent = ComponentName(packageName, "$packageName$targetAlias")
        pm.setComponentEnabledSetting(
            targetComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        val realComponent = ComponentName(packageName, "$packageName.MainActivity")
        val newState = if (presetId == "default") {
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        try {
            pm.setComponentEnabledSetting(
                realComponent,
                newState,
                PackageManager.DONT_KILL_APP
            )
        } catch (_: IllegalArgumentException) {
            // Component not registered as a separate launcher entry on this build.
        }

        return true
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val timeStr = SmsBootReceiver.readStoredReminderTime(this) ?: "08:00"
        val data = Data.Builder()
            .putString(SmsReminderWorker.KEY_TIME, timeStr)
            .build()
        val request = PeriodicWorkRequestBuilder<SmsReminderWorker>(1, TimeUnit.DAYS)
            .setInputData(data)
            .build()
        WorkManager.getInstance(this)
            .enqueueUniquePeriodicWork(SmsReminderWorker.UNIQUE_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
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
