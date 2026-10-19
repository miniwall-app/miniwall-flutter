package com.miniwall.flutter

import android.app.Activity
import android.content.Context
import com.miniwall.sdk.MiniwallBridge
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/** Flutter plugin: forwards calls to [MiniwallBridge] and the screen's requests back to Dart. */
class MiniwallFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var auto: MiniwallBridge? = null

    /** Requests waiting for Dart (purchase, restore, action). */
    private val waiting = ConcurrentHashMap<Int, (Any?) -> Unit>()
    private val nextWaiting = AtomicInteger()
    private val fireAndForget = setOf("answer", "openUrl", "error", "autoResult")

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "miniwall")
        channel.setMethodCallHandler(this)
    }

    /** The engine is going away (hot restart, activity destroyed): stop auto placements and free every waiting screen. */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try { bridge("").stopAutoPlacements(emptyMap()) } catch (e: IllegalStateException) { /* never configured */ }
        auto = null
        val replies = waiting.values.toList()
        waiting.clear()
        replies.forEach { it(null) }
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    /**
     * An error or a missing handler on the Dart side. Purchase, restore and action get `{error}`: the native onError
     * fires, nothing is credited, and an action keeps the screen open. Other requests get null.
     */
    private fun failure(method: String, message: String): Any? =
        if (method == "purchase" || method == "restore" || method == "action") mapOf("error" to message) else null

    private fun bridge(presentationId: String) = MiniwallBridge { method, arguments, reply ->
        val args = arguments + ("presentationId" to presentationId)
        if (method in fireAndForget) {
            // answer, openUrl, error, autoResult: nobody waits for Dart.
            channel.invokeMethod(method, args)
            return@MiniwallBridge reply(null)
        }
        val id = nextWaiting.incrementAndGet()
        waiting[id] = reply
        channel.invokeMethod(method, args, object : MethodChannel.Result {
            // Already answered "no" by onDetachedFromEngine: ignore a late reply.
            override fun success(result: Any?) { waiting.remove(id)?.invoke(result) }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) { waiting.remove(id)?.invoke(failure(method, errorMessage ?: errorCode)) }
            override fun notImplemented() { waiting.remove(id)?.invoke(failure(method, "Miniwall: $method is not handled on the Dart side")) }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
        val bridge = bridge(args["presentationId"] as? String ?: "")
        when (call.method) {
            "configure" -> { bridge.configure(context, args); result.success(null) }
            "setAttributes" -> { bridge.setAttributes(args); result.success(null) }
            "reportPurchase" -> { bridge.reportPurchase(args); result.success(null) }
            "reset" -> { bridge.reset(args); result.success(null) }
            "track" -> { bridge.track(args); result.success(null) }
            "startAutoPlacements" -> {
                val autoBridge = bridge("auto")
                auto = autoBridge
                autoBridge.startAutoPlacements(args, activity)
                result.success(null)
            }
            "stopAutoPlacements" -> { bridge.stopAutoPlacements(args); auto = null; result.success(null) }
            "preload" -> bridge.preload(args) { result.success(null) }
            "present" -> {
                val host = activity ?: return result.error("miniwall_error", "Miniwall: no activity", null)
                bridge.present(host, args) { value, error ->
                    if (error != null) result.error("miniwall_error", error.message, null) else result.success(value)
                }
            }
            else -> result.notImplemented()
        }
    }
}
