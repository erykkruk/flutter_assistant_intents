package tech.ravenlab.flutter_assistant_intents

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

/**
 * Publishes the plugin's dynamic app shortcuts ("Add task", "Today").
 * Labels come from the Dart side so host apps can localize them.
 *
 * Shortcuts are published with [ShortcutManagerCompat.pushDynamicShortcut]
 * (additive, not rate-limited, reports usage) so the host app's own dynamic
 * shortcuts are never replaced or removed.
 */
internal object ShortcutsPublisher {

    private const val SHORTCUT_ID_ADD_TASK = "flutter_assistant_intents.add_task"
    private const val SHORTCUT_ID_QUERY_TODAY = "flutter_assistant_intents.query_today"

    private const val DEFAULT_ADD_LABEL = "Add task"
    private const val DEFAULT_ADD_LONG_LABEL = "Add a new task"
    private const val DEFAULT_TODAY_LABEL = "Today"
    private const val DEFAULT_TODAY_LONG_LABEL = "Show today's tasks"

    private const val RANK_ADD_TASK = 0
    private const val RANK_QUERY_TODAY = 1
    private const val RANK_CUSTOM_BASE = 2

    fun publish(context: Context, config: Map<*, *>?) {
        if (config?.get("publishTaskShortcuts") as? Boolean != false) {
            publishTaskShortcuts(context, config)
        }
        publishCustomShortcuts(context, config?.get("customShortcuts") as? List<*>)
    }

    private fun publishTaskShortcuts(context: Context, labels: Map<*, *>?) {
        val addShortcut = buildShortcut(
            context = context,
            id = SHORTCUT_ID_ADD_TASK,
            action = FlutterAssistantIntentsPlugin.ACTION_ADD_TASK,
            label = labels.string("addTaskLabel") ?: DEFAULT_ADD_LABEL,
            longLabel = labels.string("addTaskLongLabel") ?: DEFAULT_ADD_LONG_LABEL,
            iconRes = R.drawable.flutter_assistant_intents_add_task,
            rank = RANK_ADD_TASK,
        )
        val todayShortcut = buildShortcut(
            context = context,
            id = SHORTCUT_ID_QUERY_TODAY,
            action = FlutterAssistantIntentsPlugin.ACTION_QUERY_TODAY,
            label = labels.string("queryTodayLabel") ?: DEFAULT_TODAY_LABEL,
            longLabel = labels.string("queryTodayLongLabel") ?: DEFAULT_TODAY_LONG_LABEL,
            iconRes = R.drawable.flutter_assistant_intents_today,
            rank = RANK_QUERY_TODAY,
        )
        ShortcutManagerCompat.pushDynamicShortcut(context, addShortcut)
        ShortcutManagerCompat.pushDynamicShortcut(context, todayShortcut)
    }

    private fun publishCustomShortcuts(context: Context, customShortcuts: List<*>?) {
        customShortcuts.orEmpty().forEachIndexed { index, raw ->
            val entry = raw as? Map<*, *> ?: return@forEachIndexed
            val id = entry.string("id") ?: return@forEachIndexed
            val action = entry.string("action") ?: return@forEachIndexed
            val shortcut = buildShortcut(
                context = context,
                id = id,
                action = FlutterAssistantIntentsPlugin.CUSTOM_ACTION_PREFIX + action,
                label = entry.string("shortLabel") ?: action,
                longLabel = entry.string("longLabel")
                    ?: entry.string("shortLabel")
                    ?: action,
                iconRes = R.drawable.flutter_assistant_intents_action,
                rank = RANK_CUSTOM_BASE + index,
            )
            ShortcutManagerCompat.pushDynamicShortcut(context, shortcut)
        }
    }

    private fun buildShortcut(
        context: Context,
        id: String,
        action: String,
        label: String,
        longLabel: String,
        iconRes: Int,
        rank: Int,
    ): ShortcutInfoCompat {
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: throw IllegalStateException(
                "No launch intent for package ${context.packageName}; " +
                    "cannot publish app shortcuts",
            )
        launchIntent.putExtra(FlutterAssistantIntentsPlugin.EXTRA_ACTION, action)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setLongLabel(longLabel)
            .setIcon(IconCompat.createWithResource(context, iconRes))
            .setRank(rank)
            .setIntent(launchIntent)
            .build()
    }

    private fun Map<*, *>?.string(key: String): String? =
        (this?.get(key) as? String)?.takeIf { it.isNotBlank() }
}
