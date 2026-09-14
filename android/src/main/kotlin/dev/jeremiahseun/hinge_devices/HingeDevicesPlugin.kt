package dev.jeremiahseun.hinge_devices

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.window.layout.FoldingFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android implementation of the foldable runtime.
 *
 * The native side reports facts only — a folding feature, a sensor reading,
 * window metrics. Posture derivation, angle normalisation and deduplication
 * all happen in Dart, so the rules are identical on every platform and
 * testable without hardware.
 */
class HingeDevicesPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    EventChannel.StreamHandler {

    private companion object {
        const val METHOD_CHANNEL = "dev.jeremiahseun/hinge_devices"
        const val EVENT_CHANNEL = "dev.jeremiahseun/hinge_devices/events"
        const val SPEC_VERSION = 1
    }

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    private var hingeSensor: HingeSensorSource? = null
    private var displays: DisplaySource? = null
    private val windowLayout = WindowLayoutSource { _, _, _ -> emitState() }

    private var angleUpdatesEnabled = false
    private var windowWidth = 0
    private var windowHeight = 0

    private var activeDisplayCache = "unknown"
    private var activeDisplayCacheKey = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        hingeSensor = HingeSensorSource(context) { emitState() }
        displays = DisplaySource(context)

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@HingeDevicesPlugin)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@HingeDevicesPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        hingeSensor?.stop()
        windowLayout.stop()
    }

    // --- ActivityAware -----------------------------------------------------
    //
    // WindowInfoTracker needs an Activity. When one is not attached we fall
    // back to sensor-only reporting rather than failing.

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        windowLayout.start(binding.activity)
        if (sink != null) hingeSensor?.start(fast = angleUpdatesEnabled)
        emitState()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Unfolding *is* a configuration change, so this fires at exactly the
        // moment posture is changing. Only the window-layout observer is torn
        // down here; the sensor keeps delivering so the state that arrives
        // after reattach is current rather than the reading from before the
        // fold.
        windowLayout.stop()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        windowLayout.stop()
        hingeSensor?.stop()
        activity = null
    }

    // --- MethodCallHandler -------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "capabilities" -> result.success(capabilities())
            // Read live rather than from the cached capability snapshot: the
            // whole point is what the sensor has done since the app started.
            "diagnostics" -> result.success(diagnostics())
            "setAngleUpdatesEnabled" -> {
                angleUpdatesEnabled = call.argument<Boolean>("enabled") ?: false
                // Never stops the sensor: posture still needs it to tell a
                // shut device from an open one. Only the rate changes.
                if (sink != null) hingeSensor?.start(fast = angleUpdatesEnabled)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun capabilities(): Map<String, Any?> {
        val hasSensor = hingeSensor?.isAvailable == true
        val hasFeature = windowLayout.hasSeenFeature
        return mapOf(
            "isFoldable" to (hasSensor || hasFeature),
            "hingeAngleSensor" to hasSensor,
            "foldingFeature" to (activity != null),
                "outerDisplay" to (displays?.hasOuterDisplay() ?: false),
            "sceneAccessory" to false,
            "rearDisplayTransfer" to false,
            "dualConcurrent" to false,
            "specVersion" to SPEC_VERSION,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
        )
    }

    private fun diagnostics(): Map<String, Any?> {
        return buildMap {
            put("manufacturer", Build.MANUFACTURER)
            put("model", Build.MODEL)
            put("sdkInt", Build.VERSION.SDK_INT)
            put("activeDisplay", cachedActiveDisplay())
            put("windowWidth", windowWidth)
            put("windowHeight", windowHeight)
            putAll(hingeSensor?.stats() ?: emptyMap())
        }
    }

    // --- EventChannel.StreamHandler ---------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // The hinge sensor runs even when angle updates are off: it is the
        // only signal that can distinguish a shut device, which reports no
        // folding feature. Angle updates raise its rate, they do not turn it
        // on.
        hingeSensor?.start(fast = angleUpdatesEnabled)
        activity?.let(windowLayout::start)
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        hingeSensor?.stop()
        windowLayout.stop()
    }

    /**
     * Builds and delivers a state snapshot.
     *
     * Always hops to the main thread first. The hinge sensor calls back on
     * the sensor thread, and the window and display APIs this reads are not
     * safe to touch from there — doing so threw inside onSensorChanged and
     * silently killed every angle update, while main-thread window-layout
     * callbacks kept working. Hence also the catch: one bad read must not
     * take the stream down.
     */
    private fun emitState() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            emitStateOnMainThread()
        } else {
            mainHandler.post(::emitStateOnMainThread)
        }
    }

    private fun emitStateOnMainThread() {
        try {
            buildAndSend()
        } catch (error: Throwable) {
            android.util.Log.w(
                "hinge_devices",
                "dropped a state update: ${error.message}",
            )
        }
    }

    /**
     * Which display the app is on, recomputed only when the window resizes.
     *
     * Enumerating displays is not free, and the hinge sensor can fire many
     * times a second while an angle-driven effect is running. The window size
     * is the only input that can change the answer.
     */
    private fun cachedActiveDisplay(): String {
        val key = windowWidth.toLong() shl 32 or windowHeight.toLong()
        if (key != activeDisplayCacheKey) {
            activeDisplayCacheKey = key
            activeDisplayCache = displays?.activeDisplay(activity) ?: "unknown"
        }
        return activeDisplayCache
    }

    private fun buildAndSend() {
        val sink = this.sink ?: return
        val density = context.resources.displayMetrics.density
        val feature = windowLayout.lastFeature
        val metrics = context.resources.displayMetrics
        windowWidth = metrics.widthPixels
        windowHeight = metrics.heightPixels

        val payload = mutableMapOf<String, Any?>(
            "featureState" to when (feature?.state) {
                FoldingFeature.State.FLAT -> "flat"
                FoldingFeature.State.HALF_OPENED -> "halfOpened"
                else -> null
            },
            "featureOrientation" to when (feature?.orientation) {
                FoldingFeature.Orientation.HORIZONTAL -> "horizontal"
                FoldingFeature.Orientation.VERTICAL -> "vertical"
                else -> null
            },
            "hingeAngle" to hingeSensor?.lastAngle?.toDouble(),
            "activeDisplay" to cachedActiveDisplay(),
            "windowWidth" to windowWidth / density,
            "windowHeight" to windowHeight / density,
        )

        if (feature != null) {
            payload["features"] = listOf(
                mapOf(
                    "left" to feature.bounds.left / density,
                    "top" to feature.bounds.top / density,
                    "right" to feature.bounds.right / density,
                    "bottom" to feature.bounds.bottom / density,
                    "isSeparating" to feature.isSeparating,
                    "occlusion" to when (feature.occlusionType) {
                        FoldingFeature.OcclusionType.FULL -> "full"
                        FoldingFeature.OcclusionType.NONE -> "none"
                        else -> "unknown"
                    },
                ),
            )
        }

        sink.success(payload)
    }
}
