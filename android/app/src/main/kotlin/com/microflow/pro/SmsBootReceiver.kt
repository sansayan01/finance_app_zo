package com.microflow.pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class SmsBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsBootReceiver"
        private const val PREFS = "sms_reminder_prefs"
        private const val KEY_TIME = "reminder_time"
        const val DEFAULT_TIME = "08:00"

        fun readStoredReminderTime(context: Context): String? {
            return try {
                prefs(context).getString(KEY_TIME, null)
            } catch (_: Exception) {
                null
            }
        }

        fun writeStoredReminderTime(context: Context, timeStr: String) {
            try {
                prefs(context).edit().putString(KEY_TIME, timeStr).apply()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to persist reminder time: ${e.message}")
            }
        }

        private fun prefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.d(TAG, "Boot completed — rescheduling SMS reminder worker")
        val timeStr = readStoredReminderTime(context) ?: DEFAULT_TIME
        val data = Data.Builder()
            .putString(SmsReminderWorker.KEY_TIME, timeStr)
            .build()
        val request = PeriodicWorkRequestBuilder<SmsReminderWorker>(1, TimeUnit.DAYS)
            .setInputData(data)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                SmsReminderWorker.UNIQUE_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
    }
}
