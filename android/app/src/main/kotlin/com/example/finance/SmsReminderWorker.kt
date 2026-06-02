package com.example.finance

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterMain
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SmsReminderWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    companion object {
        private const val TAG = "SmsReminderWorker"
        const val UNIQUE_NAME = "sms_reminder"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            FlutterMain.startInitialization(applicationContext)
            val engine = FlutterEngine(applicationContext)
            val messenger = engine.dartExecutor.binaryMessenger
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            val channel = MethodChannel(messenger, "com.microflow/sms_scheduler")
            channel.invokeMethod("run_reminder_pass", null)
            engine.destroy()
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Reminder worker failed: ${e.message}", e)
            Result.retry()
        }
    }
}
