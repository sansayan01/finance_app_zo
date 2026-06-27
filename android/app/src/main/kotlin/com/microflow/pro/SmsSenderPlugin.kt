package com.microflow.pro

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

class SmsSenderPlugin(
    private val context: Context,
    private val channel: MethodChannel,
    private var activity: Activity? = null
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 10011
        private const val TAG = "SmsSenderPlugin"
        private const val SMS_SENT_ACTION = "com.microflow.pro.SMS_SENT"
        private const val SLOT_DEFAULT = -1
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private val pendingById: ConcurrentHashMap<String, PendingSend> = ConcurrentHashMap()
    private var cachedSubscriptionId: Int = SLOT_DEFAULT

    private data class PendingSend(
        val phone: String,
        val parts: Int,
        val sentCount: AtomicInteger = AtomicInteger(0),
        val failureCount: AtomicInteger = AtomicInteger(0),
        val result: MethodChannel.Result,
    )

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != SMS_SENT_ACTION) return

            val requestId = intent.getStringExtra("request_id") ?: return
            val partIndex = intent.getIntExtra("part_index", -1)
            val p = pendingById[requestId] ?: return

            val code = resultCode
            if (code != Activity.RESULT_OK) {
                p.failureCount.incrementAndGet()
                Log.e(TAG, "SMS part $partIndex for req=$requestId failed with code $code")
            } else {
                p.sentCount.incrementAndGet()
            }

            if (p.sentCount.get() + p.failureCount.get() == p.parts) {
                val removed = pendingById.remove(requestId) ?: return
                if (removed.failureCount.get() > 0) {
                    removed.result.error("SEND_FAILED", "${removed.failureCount.get()}/${removed.parts} parts failed", null)
                } else {
                    removed.result.success(true)
                }
            }
        }
    }

    init {
        val filter = IntentFilter(SMS_SENT_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(smsReceiver, filter)
        }
    }

    fun setActivity(act: Activity?) {
        this.activity = act
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "send_sms" -> {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                val requestId = call.argument<String>("request_id")
                val subscriptionId = call.argument<Int>("subscription_id") ?: SLOT_DEFAULT
                if (phone.isNullOrEmpty() || message.isNullOrEmpty() || requestId.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "phone, message, request_id are required", null)
                    return
                }
                sendSms(phone, message, requestId, subscriptionId, result)
            }
            "check_permission" -> result.success(hasSmsPermission())
            "request_permission" -> requestSmsPermission(result)
            "pick_subscription" -> {
                if (!hasSmsPermission()) {
                    result.error("NEEDS_SMS_PERMISSION", "SMS permission required", null)
                    return
                }
                val subs = activeSubscriptions()
                if (subs.isEmpty()) {
                    result.success(syntheticDefaultSubscription())
                } else {
                    val payload = subs.map { mapOf(
                        "subscription_id" to it.subscriptionId,
                        "sim_slot_index" to it.simSlotIndex,
                        "carrier_name" to (it.carrierName?.toString() ?: ""),
                        "display_name" to (it.displayName?.toString() ?: ""),
                    ) }
                    result.success(payload)
                }
            }
            "open_app_settings" -> {
                val act = activity
                if (act != null) {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.fromParts("package", act.packageName, null)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    act.startActivity(intent)
                    result.success(true)
                } else {
                    result.error("NO_ACTIVITY", "Cannot open settings without activity", null)
                }
            }
            "set_subscription" -> {
                val id = call.argument<Int>("subscription_id") ?: SLOT_DEFAULT
                cachedSubscriptionId = id
                result.success(true)
            }
            "get_subscription" -> result.success(cachedSubscriptionId)
            else -> result.notImplemented()
        }
    }

    private fun activeSubscriptions(): List<SubscriptionInfo> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return emptyList()
        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            return emptyList()
        }
        val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
        return sm?.activeSubscriptionInfoList ?: emptyList()
    }

    private fun findWorkingSubscriptionId(): Int {
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
            ?: return SLOT_DEFAULT

        for (sub in activeSubscriptions()) {
            val subTm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                tm.createForSubscriptionId(sub.subscriptionId)
            } else {
                tm
            }
            val state = subTm.serviceState?.state
            if (state == android.telephony.ServiceState.STATE_IN_SERVICE) {
                Log.d(TAG, "Found working SIM: subId=${sub.subscriptionId}, carrier=${sub.carrierName}")
                return sub.subscriptionId
            }
        }
        Log.w(TAG, "No SIM with cellular service found")
        return SLOT_DEFAULT
    }

    private fun syntheticDefaultSubscription(): List<Map<String, Any?>> {
        return listOf(
            mapOf(
                "subscription_id" to -1,
                "sim_slot_index" to 0,
                "carrier_name" to "Default",
                "display_name" to "Default SIM",
            )
        )
    }

    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Cannot request permission in background", null)
            return
        }
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(act, arrayOf(android.Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST_CODE)
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    private fun sendSms(phone: String, message: String, requestId: String, subIdArg: Int, result: MethodChannel.Result) {
        try {
            if (!hasSmsPermission()) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            var subId = if (subIdArg != SLOT_DEFAULT) subIdArg else cachedSubscriptionId

            if (subId == SLOT_DEFAULT) {
                val workingSubId = findWorkingSubscriptionId()
                if (workingSubId != SLOT_DEFAULT) {
                    subId = workingSubId
                    Log.d(TAG, "Auto-selected working SIM subscription: $subId")
                }
            }

            @Suppress("DEPRECATION")
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val base = context.getSystemService(SmsManager::class.java)
                if (subId != SLOT_DEFAULT) base.createForSubscriptionId(subId) else base
            } else {
                if (subId != SLOT_DEFAULT && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    SmsManager.getSmsManagerForSubscriptionId(subId)
                } else {
                    SmsManager.getDefault()
                }
            }

            val parts = smsManager.divideMessage(message)
            if (parts.isEmpty()) {
                result.error("EMPTY_MESSAGE", "Message divided into 0 parts", null)
                return
            }

            val pending = PendingSend(phone, parts.size, result = result)
            pendingById[requestId] = pending

            val sentIntents = ArrayList<PendingIntent>(parts.size)
            for (i in parts.indices) {
                val intent = Intent(SMS_SENT_ACTION).apply {
                    putExtra("request_id", requestId)
                    putExtra("part_index", i)
                    `package` = context.packageName
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                sentIntents.add(PendingIntent.getBroadcast(context, (requestId + i).hashCode(), intent, flags))
            }

            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, ArrayList(parts), sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntents[0], null)
            }
            Log.d(TAG, "Sent SMS to $phone (req=$requestId, parts=${parts.size})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS", e)
            pendingById.remove(requestId)
            result.error("SEND_FAILED", e.message, null)
        }
    }
}
