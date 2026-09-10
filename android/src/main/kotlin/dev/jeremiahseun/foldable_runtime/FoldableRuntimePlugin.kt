package dev.jeremiahseun.foldable_runtime

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
class FoldableRuntimePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    EventChannel.StreamHandler {

    private companion object {
        const val METHOD_CHANNEL = "dev.jeremiahseun/foldable_runtime"
        const val EVENT_CHANNEL = "dev.jeremiahseun/foldable_runtime/events"
        const val SPEC_VERSION = 1
    }

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    private var hingeSensor: HingeSensorSource? = null
    private val windowLayout = WindowLayoutSource { _, _, _ -> emitState() }

    private var angleUpdatesEnabled = false
    private var windowWidth = 0
    private var windowHeight = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        hingeSensor = HingeSensorSource(context) { emitState() }

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@FoldableRuntimePlugin)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@FoldableRuntimePlugin)
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
        if (sink != null) hingeSensor?.start()
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

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
            "setAngleUpdatesEnabled" -> {
                angleUpdatesEnabled = call.argument<Boolean>("enabled") ?: false
                if (angleUpdatesEnabled) hingeSensor?.start() else hingeSensor?.stop()
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
            // v0.1 does not probe cover displays; v0.2 adds DisplayManager
            // inspection. Reported explicitly rather than omitted so callers
            // can tell "no" from "unknown".
            "outerDisplay" to false,
            "sceneAccessory" to false,
            "rearDisplayTransfer" to false,
            "dualConcurrent" to false,
            "specVersion" to SPEC_VERSION,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
        )
    }

    // --- EventChannel.StreamHandler ---------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // The hinge sensor is started even when angle updates are off: it is
        // the only signal that can distinguish a closed device, which no
        // folding feature reports. Angle values are still gated in Dart.
        hingeSensor?.start()
        activity?.let(windowLayout::start)
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        hingeSensor?.stop()
        windowLayout.stop()
    }

    private fun emitState() {
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
            "activeDisplay" to "unknown",
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

        mainHandler.post { sink.success(payload) }
    }
}
