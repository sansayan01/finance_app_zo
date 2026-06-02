package com.example.finance

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

class SmsReminderWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    companion object {
        private const val TAG = "SmsReminderWorker"
        const val UNIQUE_NAME = "sms_reminder"
        const val UNIQUE_RESCHEDULE_NAME = "sms_reminder_next"
        const val KEY_TIME = "reminder_time"

        /** Compute the millis-from-now delay until the next occurrence of
         *  the given "HH:mm" time. If the time has already passed today,
         *  schedules for tomorrow at the same time. */
        fun delayUntilNextOccurrence(timeStr: String, now: LocalDateTime = LocalDateTime.now()): Long {
            val parsed = runCatching { LocalTime.parse(timeStr) }.getOrNull()
                ?: return TimeUnit.DAYS.toMillis(1)
            val today = now.toLocalDate()
            val targetToday = LocalDateTime.of(today, parsed)
            val target = if (targetToday.isAfter(now)) targetToday else targetToday.plusDays(1)
            val zone = ZoneId.systemDefault()
            val millis = Duration.between(
                now.atZone(zone),
                target.atZone(zone)
            ).toMillis()
            return millis.coerceAtLeast(0L)
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.Main) {
        val inputTime = inputData.getString(KEY_TIME)
            ?: SmsBootReceiver.readStoredReminderTime(applicationContext)
            ?: "08:00"

        var engine: FlutterEngine? = null
        try {
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

            // Reschedule ourselves for the next user-selected time. The
            // periodic work keeps running (KEEP) so this is a safety net
            // that fires at the exact user-chosen minute.
            try {
                val delayMillis = delayUntilNextOccurrence(inputTime)
                val data = Data.Builder()
                    .putString(KEY_TIME, inputTime)
                    .build()
                val oneShot = OneTimeWorkRequestBuilder<SmsReminderWorker>()
                    .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
                    .setInputData(data)
                    .build()
                WorkManager.getInstance(applicationContext).enqueueUniqueWork(
                    UNIQUE_RESCHEDULE_NAME,
                    ExistingWorkPolicy.REPLACE,
                    oneShot
                )
                Log.d(TAG, "Rescheduled next pass in ${delayMillis}ms at $inputTime")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to reschedule next pass: ${e.message}")
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
