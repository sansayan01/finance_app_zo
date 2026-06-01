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
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsSenderPlugin(
    private val activity: Activity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val SMS_PERMISSION_REQUEST_CODE = 10011
        private const val TAG = "SmsSenderPlugin"
        private const val SMS_SENT_ACTION = "com.example.finance.SMS_SENT"
        private const val SMS_DELIVERED_ACTION = "com.example.finance.SMS_DELIVERED"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var smsResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "send_sms" -> {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                if (phone.isNullOrEmpty() || message.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "Phone and message are required", null)
                    return
                }
                sendSms(phone, message, result)
            }
            "check_permission" -> {
                result.success(hasSmsPermission())
            }
            "request_permission" -> {
                requestSmsPermission(result)
            }
            else -> result.notImplemented()
        }
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
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
            return true
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun sendSms(phone: String, message: String, result: MethodChannel.Result) {
        try {
            if (!hasSmsPermission()) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                activity.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }

            // Store result to reply after PendingIntent callback
            smsResult = result

            // Create PendingIntents for send/delivery confirmation
            val sentIntent = PendingIntent.getBroadcast(
                activity, 0,
                Intent(SMS_SENT_ACTION),
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val deliveredIntent = PendingIntent.getBroadcast(
                activity, 0,
                Intent(SMS_DELIVERED_ACTION),
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )

            // Register receiver for send result
            activity.registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    val r = smsResult
                    smsResult = null
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            Log.d(TAG, "SMS sent successfully to $phone")
                            r?.success(true)
                        }
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                            Log.e(TAG, "SMS generic failure to $phone")
                            r?.error("SEND_FAILED", "Generic failure", null)
                        }
                        SmsManager.RESULT_ERROR_NO_SERVICE -> {
                            Log.e(TAG, "SMS no service for $phone")
                            r?.error("NO_SERVICE", "No cellular service", null)
                        }
                        SmsManager.RESULT_ERROR_NULL_PDU -> {
                            Log.e(TAG, "SMS null PDU for $phone")
                            r?.error("NULL_PDU", "Null PDU", null)
                        }
                        SmsManager.RESULT_ERROR_RADIO_OFF -> {
                            Log.e(TAG, "SMS radio off for $phone")
                            r?.error("RADIO_OFF", "Airplane mode or radio off", null)
                        }
                        else -> {
                            Log.e(TAG, "SMS unknown error ($resultCode) to $phone")
                            r?.error("SEND_FAILED", "Unknown error code: $resultCode", null)
                        }
                    }
                    try { activity.unregisterReceiver(this) } catch (_: Exception) {}
                }
            }, IntentFilter(SMS_SENT_ACTION), Context.RECEIVER_NOT_EXPORTED)

            // Register receiver for delivery result
            activity.registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    when (resultCode) {
                        Activity.RESULT_OK -> Log.d(TAG, "SMS delivered to $phone")
                        else -> Log.w(TAG, "SMS NOT delivered to $phone (code: $resultCode)")
                    }
                    try { activity.unregisterReceiver(this) } catch (_: Exception) {}
                }
            }, IntentFilter(SMS_DELIVERED_ACTION), Context.RECEIVER_NOT_EXPORTED)

            // Send the SMS with proper PendingIntents
            if (message.length > 160) {
                val parts = smsManager.divideMessage(message)
                val sentIntents = ArrayList<PendingIntent?>().apply { for (i in parts.indices) add(sentIntent) }
                val deliveredIntents = ArrayList<PendingIntent?>().apply { for (i in parts.indices) add(deliveredIntent) }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, deliveredIntents)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntent, deliveredIntent)
            }

            Log.d(TAG, "SMS dispatch initiated to $phone (${message.length} chars)")
            // Do NOT call result.success here — the BroadcastReceiver will handle it
        } catch (e: Exception) {
            Log.e(TAG, "SMS exception to $phone: ${e.message}", e)
            smsResult = null
            result.error("SEND_FAILED", e.message, null)
        }
    }
}
