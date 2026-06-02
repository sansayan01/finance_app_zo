package com.example.finance

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

class SmsReminderWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    companion object {
        private const val TAG = "SmsReminderWorker"
        const val UNIQUE_NAME = "sms_reminder"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.Main) {
        var engine: FlutterEngine? = null
        try {
            // Modern Flutter (>= 2.x) initializes the engine automatically
            // when FlutterEngine is constructed. FlutterMain.startInitialization
            // and FlutterMain.ensureInitializationComplete are no longer
            // required and have been removed from io.flutter.view.
            engine = FlutterEngine(applicationContext)
            val messenger = engine.dartExecutor.binaryMessenger
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            val channel = MethodChannel(messenger, "com.microflow/sms_scheduler")
            // Suspend until the Dart side completes the pass
            suspendCancellableCoroutine<Unit> { cont ->
                channel.invokeMethod("run_reminder_pass", null, object : MethodChannel.Result {
                    override fun success(result: Any?) { cont.resume(Unit) {} }
                    override fun error(code: String, msg: String?, details: Any?) {
                        cont.resumeWithException(RuntimeException("sms_scheduler: $code: $msg"))
                    }
                    override fun notImplemented() {
                        cont.resumeWithException(RuntimeException("sms_scheduler: not implemented"))
                    }
                })
            }
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Reminder worker failed: ${e.message}", e)
            Result.retry()
        } finally {
            engine?.destroy()
        }
    }
}
