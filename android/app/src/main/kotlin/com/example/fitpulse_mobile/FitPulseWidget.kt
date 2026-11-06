package com.example.fitpulse_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Date
import java.util.Locale

/**
 * Widget de FitPulse para la pantalla de inicio.
 * La app manda los datos del día por el canal "fitpulse/widget" (ver MainActivity);
 * aquí se guardan en SharedPreferences y se dibuja el widget con esos valores.
 */
class FitPulseWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, buildViews(context))
    }

    companion object {
        private const val PREFS = "fitpulse_widget"

        /** Guarda los datos que mandó Flutter y redibuja todos los widgets. */
        fun save(context: Context, data: Map<*, *>) {
            val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            e.putBoolean("signedIn", true)
            e.putString("name", data["name"] as? String ?: "")
            e.putLong("steps", (data["steps"] as? Number)?.toLong() ?: 0L)
            e.putLong("goal", (data["goal"] as? Number)?.toLong() ?: 10000L)
            e.putLong("calories", (data["calories"] as? Number)?.toLong() ?: 0L)
            e.putLong("heartRate", (data["heartRate"] as? Number)?.toLong() ?: -1L)
            e.putString("lastSession", data["lastSession"] as? String)
            e.putLong("updatedAt", (data["updatedAt"] as? Number)?.toLong() ?: System.currentTimeMillis())
            e.apply()
            refresh(context)
        }

        /** Al cerrar sesión el widget vuelve a su estado vacío. */
        fun clear(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            refresh(context)
        }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FitPulseWidget::class.java))
            for (id in ids) manager.updateAppWidget(id, buildViews(context))
        }

        private fun buildViews(context: Context): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.fitpulse_widget)
            val nf = NumberFormat.getIntegerInstance(Locale("es", "MX"))

            if (!p.getBoolean("signedIn", false)) {
                views.setTextViewText(R.id.widget_steps, "--")
                views.setTextViewText(R.id.widget_goal, "Inicia sesión para ver tu día")
                views.setTextViewText(R.id.widget_percent, "")
                views.setProgressBar(R.id.widget_progress, 100, 0, false)
                views.setTextViewText(R.id.widget_calories, "")
                views.setTextViewText(R.id.widget_heart, "")
                views.setTextViewText(R.id.widget_last, "")
                views.setTextViewText(R.id.widget_updated, "")
            } else {
                val steps = p.getLong("steps", 0L)
                val goal = p.getLong("goal", 10000L).coerceAtLeast(1L)
                val percent = ((steps * 100) / goal).toInt()
                val hr = p.getLong("heartRate", -1L)
                val last = p.getString("lastSession", null)
                val updated = p.getLong("updatedAt", 0L)

                views.setTextViewText(R.id.widget_steps, nf.format(steps))
                views.setTextViewText(R.id.widget_goal, "de ${nf.format(goal)} pasos")
                views.setTextViewText(R.id.widget_percent, "${percent.coerceAtMost(999)}%")
                views.setProgressBar(R.id.widget_progress, 100, percent.coerceIn(0, 100), false)
                views.setTextViewText(R.id.widget_calories, "🔥 ${nf.format(p.getLong("calories", 0L))} kcal")
                views.setTextViewText(R.id.widget_heart, if (hr > 0) "♥ $hr bpm" else "")
                views.setTextViewText(R.id.widget_last, if (last.isNullOrBlank()) "Sin entrenamientos registrados" else "Último: $last")
                views.setTextViewText(
                    R.id.widget_updated,
                    if (updated > 0) DateFormat.getTimeFormat(context).format(Date(updated)) else ""
                )
            }

            // Tocar el widget abre la app.
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            return views
        }
    }
}
