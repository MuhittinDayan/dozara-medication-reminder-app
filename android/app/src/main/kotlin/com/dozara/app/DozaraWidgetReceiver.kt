package com.dozara.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DozaraWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)
            
            val nextDose = widgetData.getString("next_dose", "--:--")
            val medicineName = widgetData.getString("medicine_name", "İlaç adı")
            val pendingCount = widgetData.getString("pending_count", "0")
            
            views.setTextViewText(R.id.widget_next_dose, "Sonraki doz: $nextDose")
            views.setTextViewText(R.id.widget_medicine_name, medicineName)
            views.setTextViewText(R.id.widget_pending_count, "$pendingCount bekleyen doz")
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
