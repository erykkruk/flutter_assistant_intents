package dev.erykkruk.flutter_assistant_intents

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Android entry point.
 *
 * Android has no in-process voice-intent runtime comparable to iOS App
 * Intents that is broadly available yet (AppFunctions is beta and
 * Samsung-only until Android 17 — see [AppFunctionsIntegration]). The honest
 * MVP is dynamic app shortcuts: launcher long-press / Assistant-visible
 * shortcuts that launch the app with an action extra, which this plugin
 * routes into the same Dart handlers used by iOS.
 */
class FlutterAssistantIntentsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {

    companion object {
        private const val CHANNEL_NAME = "dev.erykkruk/flutter_assistant_intents"

        const val EXTRA_ACTION = "dev.erykkruk.flutter_assistant_intents.action"
        const val ACTION_ADD_TASK = "add_task"
        const val ACTION_QUERY_TODAY = "query_today"

        private const val METHOD_HANDLERS_REGISTERED = "handlers.registered"
        private const val METHOD_UPDATE_SHORTCUTS = "shortcuts.update"
        private const val METHOD_INTENT_ADD_TASK = "intent.addTask"
        private const val METHOD_INTENT_QUERY_TASKS = "intent.queryTasks"
    }

    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var handlersRegistered = false
    private var pendingAction: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
        handlersRegistered = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_HANDLERS_REGISTERED -> {
                handlersRegistered = true
                dispatchPendingAction()
                result.success(null)
            }

            METHOD_UPDATE_SHORTCUTS -> {
                val context = applicationContext
                if (context == null) {
                    result.error("no_context", "Plugin is not attached to a context", null)
                    return
                }
                try {
                    ShortcutsPublisher.publish(context, call.arguments as? Map<*, *>)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("shortcuts_failed", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // region ActivityAware — capture the launch intent from shortcuts

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        captureAction(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    override fun onNewIntent(intent: Intent): Boolean {
        val consumed = captureAction(intent)
        if (consumed) {
            activityBinding?.activity?.let { keepIntentFresh(it, intent) }
        }
        return consumed
    }

    private fun detachActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    /** Stores the shortcut action from [intent]; dispatches when Dart is ready. */
    private fun captureAction(intent: Intent?): Boolean {
        val action = intent?.getStringExtra(EXTRA_ACTION) ?: return false
        // Clear the extra so a config change does not replay the action.
        intent.removeExtra(EXTRA_ACTION)
        pendingAction = action
        if (handlersRegistered) {
            dispatchPendingAction()
        }
        return true
    }

    private fun keepIntentFresh(activity: Activity, intent: Intent) {
        activity.intent = intent
    }

    private fun dispatchPendingAction() {
        val action = pendingAction ?: return
        val channel = channel ?: return
        pendingAction = null
        when (action) {
            // Shortcuts cannot carry free-form text, so the title is empty —
            // the Dart contract documents this as "open the add-task flow".
            ACTION_ADD_TASK -> channel.invokeMethod(
                METHOD_INTENT_ADD_TASK,
                mapOf("title" to ""),
            )

            ACTION_QUERY_TODAY -> channel.invokeMethod(
                METHOD_INTENT_QUERY_TASKS,
                mapOf("filter" to "today"),
            )
        }
    }

    // endregion
}
