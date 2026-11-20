package com.doyourwork.app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.doyourwork.app.data.Store
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.engine.Reminders
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The two daily notifications (see [Reminders] for what they say and when).
 *
 * Each one is an alarm that, when it goes off, looks at this phone's chores right then: the evening
 * one stays quiet once everyone this phone looks after has picked. Then it sets itself for the next
 * day. Alarms don't survive a restart, so the phone starting up (and the app opening) sets them again.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_MORNING -> runCatching { post(context, evening = false) }
            ACTION_EVENING -> runCatching { post(context, evening = true) }
        }
        schedule(context)
    }

    companion object {
        private const val ACTION_MORNING = "com.doyourwork.app.REMINDER_MORNING"
        private const val ACTION_EVENING = "com.doyourwork.app.REMINDER_EVENING"
        private const val CHANNEL = "reminders"
        private const val PREFS = "reminders"
        private const val KEY_EVENING_HOUR = "eveningHour"
        /** A reminder that goes off this much after its time (the phone was off, say) is skipped. */
        private const val LATE_HOURS = 2L
        private const val WINDOW_MILLIS = 15 * 60_000L

        fun eveningHour(context: Context): Int {
            val h = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_EVENING_HOUR, Reminders.DEFAULT_EVENING_HOUR)
            return if (h in Reminders.EVENING_HOURS) h else Reminders.DEFAULT_EVENING_HOUR
        }

        fun setEveningHour(context: Context, hour: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt(KEY_EVENING_HOUR, hour).apply()
            schedule(context)
        }

        /** Sets the next morning and evening alarms, replacing any set before. */
        fun schedule(context: Context) {
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val now = LocalDateTime.now()
            for ((action, hour) in listOf(ACTION_MORNING to Reminders.MORNING_HOUR, ACTION_EVENING to eveningHour(context))) {
                var at = now.toLocalDate().atTime(hour, 0)
                if (!at.isAfter(now)) at = at.plusDays(1)
                val millis = at.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                // Not exact (that needs a permission Android hands out reluctantly), but within a
                // quarter of an hour: left to itself Android may hold a reminder back for an hour.
                alarms.setWindow(AlarmManager.RTC_WAKEUP, millis, WINDOW_MILLIS, pending(context, action))
            }
        }

        private fun pending(context: Context, action: String): PendingIntent =
            PendingIntent.getBroadcast(context, action.hashCode(), Intent(context, ReminderReceiver::class.java).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun post(context: Context, evening: Boolean) {
            val now = LocalDateTime.now()
            val hour = if (evening) eveningHour(context) else Reminders.MORNING_HOUR
            if (now.hour < hour || now.hour >= hour + LATE_HOURS) return
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return

            val store = Store(context)
            val family = store.family.value
            if (!family.isSetUp) return
            val zone = ZoneId.systemDefault()
            val today = LocalDate.now(zone)
            val watched = Reminders.watched(family.players.map { it.id }, store.me.value)
            if (watched.isEmpty()) return
            val logs = store.logs.value
            val cards = store.cards.value
            val still = watched.filter { id ->
                !Reminders.hasPicked(cards["$id|$today"], logs.filter { it.playerId == id && Engine.dayOf(it.timestamp, zone) == today })
            }
            if (still.isEmpty()) return

            val (title, body) = if (evening) {
                val names = still.mapNotNull { id -> family.players.firstOrNull { it.id == id }?.shownName }
                Reminders.EVENING_TITLE to Reminders.eveningBody(names, personal = watched == listOf(store.me.value))
            } else Reminders.lines.random() to Reminders.MORNING_BODY

            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Daily reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "A morning line to pick your chores, and an evening reminder if you haven't."
            })
            val open = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val n = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            NotificationManagerCompat.from(context).notify(if (evening) 2 else 1, n)
        }
    }
}
