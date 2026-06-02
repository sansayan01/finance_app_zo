package com.example.finance

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

class SmsSenderPlugin(
    private val activity: Activity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 10011
        private const val READ_PHONE_STATE_REQUEST_CODE = 10012
        private const val TAG = "SmsSenderPlugin"
        private const val SMS_SENT_ACTION = "com.example.finance.SMS_SENT"
        private const val SMS_DELIVERED_ACTION = "com.example.finance.SMS_DELIVERED"
        private const val SLOT_DEFAULT = -1
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingPickSubscriptionResult: MethodChannel.Result? = null
    // requestId -> PendingSend that tracks per-part results.
    // All parts must arrive (or time out) before we resolve the Dart result.
    private val pendingById: ConcurrentHashMap<String, PendingSend> = ConcurrentHashMap()
    private var cachedSubscriptionId: Int = SLOT_DEFAULT

    private data class PendingSend(
        val phone: String,
        val messageLength: Int,
        val parts: Int,
        val sentCount: java.util.concurrent.atomic.AtomicInteger = java.util.concurrent.atomic.AtomicInteger(0),
        val failureCount: java.util.concurrent.atomic.AtomicInteger = java.util.concurrent.atomic.AtomicInteger(0),
        val result: MethodChannel.Result,
    )

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
                if (pendingById.containsKey(requestId)) {
                    // Defensive: same id reused, drop the duplicate
                    result.error("DUPLICATE_REQUEST_ID", "request_id already in flight", null)
                    return
                }
                sendSms(phone, message, requestId, subscriptionId, result)
            }
            "check_permission" -> result.success(hasSmsPermission())
            "request_permission" -> requestSmsPermission(result)
            "pick_subscription" -> {
                if (!hasReadPhoneStatePermission()) {
                    pendingPickSubscriptionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(android.Manifest.permission.READ_PHONE_STATE),
                        READ_PHONE_STATE_REQUEST_CODE
                    )
                } else {
                    val payload = activeSubscriptions().map { mapOf(
                        "subscription_id" to it.subscriptionId,
                        "sim_slot_index" to it.simSlotIndex,
                        "carrier_name" to (it.carrierName?.toString() ?: ""),
                        "display_name" to (it.displayName?.toString() ?: ""),
                    ) }
                    result.success(payload)
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
        if (!hasReadPhoneStatePermission()) return emptyList()
        val sm = activity.getSystemService(SubscriptionManager::class.java) ?: return emptyList()
        return sm.activeSubscriptionInfoList ?: emptyList()
    }

    private fun hasReadPhoneStatePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity, android.Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity, android.Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(android.Manifest.permission.SEND_SMS),
            SMS_PERMISSION_REQUEST_CODE
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return when (requestCode) {
            SMS_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingResult?.success(granted)
                pendingResult = null
                true
            }
            READ_PHONE_STATE_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    val payload = activeSubscriptions().map { mapOf(
                        "subscription_id" to it.subscriptionId,
                        "sim_slot_index" to it.simSlotIndex,
                        "carrier_name" to (it.carrierName?.toString() ?: ""),
                        "display_name" to (it.displayName?.toString() ?: ""),
                    ) }
                    pendingPickSubscriptionResult?.success(payload)
                } else {
                    pendingPickSubscriptionResult?.success(emptyList<Map<String, Any?>>())
                }
                pendingPickSubscriptionResult = null
                true
            }
            else -> false
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(
        phone: String,
        message: String,
        requestId: String,
        subscriptionIdArg: Int,
        result: MethodChannel.Result
    ) {
        try {
            if (!hasSmsPermission()) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            val subId = if (subscriptionIdArg != SLOT_DEFAULT) subscriptionIdArg else cachedSubscriptionId
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (subId != SLOT_DEFAULT) {
                    activity.getSystemService(SmsManager::class.java)
                        .createForSubscriptionId(subId)
                } else {
                    activity.getSystemService(SmsManager::class.java)
                }
            } else {
                if (subId != SLOT_DEFAULT && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    SmsManager.getSmsManagerForSubscriptionId(subId)
                } else {
                    SmsManager.getDefault()
                }
            }

            val parts: List<String> = if (message.length > 160) {
                smsManager.divideMessage(message)
            } else listOf(message)

            val pending = PendingSend(phone, message.length, parts.size, result = result)
            pendingById[requestId] = pending

            val sentIntents = ArrayList<PendingIntent?>(parts.size)
            val deliveredIntents = ArrayList<PendingIntent?>(parts.size)
            for (i in parts.indices) {
                val sentIntent = PendingIntent.getBroadcast(
                    activity, ("$requestId:$i").hashCode(),
                    Intent("$SMS_SENT_ACTION.$requestId.$i").setPackage(activity.packageName),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                )
                val deliveredIntent = PendingIntent.getBroadcast(
                    activity, ("$requestId:d:$i").hashCode(),
                    Intent("$SMS_DELIVERED_ACTION.$requestId.$i").setPackage(activity.packageName),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                )
                sentIntents.add(sentIntent)
                deliveredIntents.add(deliveredIntent)

                registerSentReceiver(requestId, i, phone, sentIntent, "$SMS_SENT_ACTION.$requestId.$i")
                registerDeliveredReceiver(requestId, i, phone, deliveredIntent, "$SMS_DELIVERED_ACTION.$requestId.$i")
            }

            if (parts.size > 1) {
                // sendMultipartTextMessage takes a java.util.ArrayList<String>,
                // not a Kotlin List<String>. Wrap explicitly.
                smsManager.sendMultipartTextMessage(
                    phone,
                    null,
                    ArrayList(parts),
                    sentIntents,
                    deliveredIntents
                )
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntents[0], deliveredIntents[0])
            }

            Log.d(TAG, "SMS dispatch initiated to $phone (req=$requestId, parts=${parts.size}, subId=$subId)")
        } catch (e: Exception) {
            Log.e(TAG, "SMS exception to $phone: ${e.message}", e)
            pendingById.remove(requestId)
            result.error("SEND_FAILED", e.message, null)
        }
    }

    private fun registerSentReceiver(
        requestId: String,
        partIndex: Int,
        phone: String,
        pendingIntent: PendingIntent,
        action: String,
    ) {
        // The PendingIntent's underlying Intent is not directly accessible in
        // modern Android, so we pass the action string in explicitly.
        val filter = IntentFilter(action)
        activity.registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, i: Intent?) {
                val p = pendingById[requestId] ?: return
                val total = p.parts
                val code = resultCode
                val resolved: Pair<String, Any?>? = when (code) {
                    Activity.RESULT_OK -> { p.sentCount.incrementAndGet(); null }
                    SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "SEND_FAILED" to "Generic failure"
                    SmsManager.RESULT_ERROR_NO_SERVICE -> "NO_SERVICE" to "No cellular service"
                    SmsManager.RESULT_ERROR_NULL_PDU -> "NULL_PDU" to "Null PDU"
                    SmsManager.RESULT_ERROR_RADIO_OFF -> "RADIO_OFF" to "Airplane mode or radio off"
                    else -> "SEND_FAILED" to "Unknown error code: $code"
                }
                if (resolved != null) {
                    p.failureCount.incrementAndGet()
                    Log.e(TAG, "SMS part $partIndex/$total for req=$requestId to $phone failed: ${resolved.second}")
                }
                try { activity.unregisterReceiver(this) } catch (_: Exception) {}
                maybeResolve(requestId)
            }
        }, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    private fun registerDeliveredReceiver(
        requestId: String,
        partIndex: Int,
        phone: String,
        pendingIntent: PendingIntent,
        action: String,
    ) {
        val filter = IntentFilter(action)
        activity.registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, i: Intent?) {
                when (resultCode) {
                    Activity.RESULT_OK -> Log.d(TAG, "SMS part $partIndex delivered to $phone (req=$requestId)")
                    else -> Log.w(TAG, "SMS part $partIndex NOT delivered to $phone (req=$requestId, code=$resultCode)")
                }
                try { activity.unregisterReceiver(this) } catch (_: Exception) {}
            }
        }, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    private fun maybeResolve(requestId: String) {
        val p = pendingById[requestId] ?: return
        if (p.sentCount.get() + p.failureCount.get() < p.parts) return
        // First-write-wins: remove the entry first; if another thread already
        // removed it, skip resolution so we never call result.success/error twice.
        val removed = pendingById.remove(requestId) ?: return
        val total = removed.parts
        if (removed.failureCount.get() > 0) {
            removed.result.error("SEND_FAILED", "${removed.failureCount.get()}/$total parts failed", null)
        } else {
            removed.result.success(true)
        }
    }
}
