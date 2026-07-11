package dev.erykkruk.flutter_assistant_intents

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat

/**
 * Publishes the plugin's dynamic app shortcuts ("Add task", "Show today's
 * tasks"). Labels come from the Dart side so host apps can localize them.
 */
internal object ShortcutsPublisher {

    private const val SHORTCUT_ID_ADD_TASK = "flutter_assistant_intents.add_task"
    private const val SHORTCUT_ID_QUERY_TODAY = "flutter_assistant_intents.query_today"

    private const val DEFAULT_ADD_LABEL = "Add task"
    private const val DEFAULT_ADD_LONG_LABEL = "Add a new task"
    private const val DEFAULT_TODAY_LABEL = "Today's tasks"
    private const val DEFAULT_TODAY_LONG_LABEL = "Show today's tasks"

    fun publish(context: Context, labels: Map<*, *>?) {
        val addShortcut = buildShortcut(
            context = context,
            id = SHORTCUT_ID_ADD_TASK,
            action = FlutterAssistantIntentsPlugin.ACTION_ADD_TASK,
            label = labels.string("addTaskLabel") ?: DEFAULT_ADD_LABEL,
            longLabel = labels.string("addTaskLongLabel") ?: DEFAULT_ADD_LONG_LABEL,
        )
        val todayShortcut = buildShortcut(
            context = context,
            id = SHORTCUT_ID_QUERY_TODAY,
            action = FlutterAssistantIntentsPlugin.ACTION_QUERY_TODAY,
            label = labels.string("queryTodayLabel") ?: DEFAULT_TODAY_LABEL,
            longLabel = labels.string("queryTodayLongLabel") ?: DEFAULT_TODAY_LONG_LABEL,
        )
        ShortcutManagerCompat.setDynamicShortcuts(
            context,
            listOfNotNull(addShortcut, todayShortcut),
        )
    }

    private fun buildShortcut(
        context: Context,
        id: String,
        action: String,
        label: String,
        longLabel: String,
    ): ShortcutInfoCompat? {
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return null
        launchIntent.putExtra(FlutterAssistantIntentsPlugin.EXTRA_ACTION, action)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setLongLabel(longLabel)
            .setIntent(launchIntent)
            .build()
    }

    private fun Map<*, *>?.string(key: String): String? =
        (this?.get(key) as? String)?.takeIf { it.isNotBlank() }
}
