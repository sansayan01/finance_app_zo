package com.example.finance

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class SmsBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.d(TAG, "Boot completed — rescheduling SMS reminder worker")
        val request = PeriodicWorkRequestBuilder<SmsReminderWorker>(1, TimeUnit.DAYS).build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                SmsReminderWorker.UNIQUE_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
    }
}
