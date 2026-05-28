package com.example.finance

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
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
    }

    private var pendingResult: MethodChannel.Result? = null

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

            // Split long messages into parts
            if (message.length > 160) {
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message, null)
        }
    }
}
