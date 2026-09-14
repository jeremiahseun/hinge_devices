package dev.jeremiahseun.hinge_devices

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.window.layout.FoldingFeature
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import dev.jeremiahseun.hinge_devices.core.DisplaySource
import dev.jeremiahseun.hinge_devices.core.HingeSensorSource
import dev.jeremiahseun.hinge_devices.core.WindowLayoutSource

/**
 * The React Native implementation of the foldable runtime.
 *
 * Mirrors the Flutter plugin exactly, and shares its hardware sources with it
 * — [HingeSensorSource], [WindowLayoutSource] and [DisplaySource] are
 * vendored from `shared/android/` by `tool/sync_shared.dart`, and CI fails if
 * the two copies drift. Every bug found on real hardware is therefore fixed
 * once for both frameworks.
 *
 * The native side reports *facts* only — a folding feature, a sensor reading,
 * window metrics. Posture derivation, angle normalisation and deduplication
 * all happen in TypeScript, so the rules are identical to the Dart
 * implementation and testable without a device.
 */
class HingeDevicesModule(
    private val reactContext: ReactApplicationContext,
) : NativeHingeDevicesSpec(reactContext), LifecycleEventListener {

    companion object {
        const val NAME = "HingeDevices"
        private const val EVENT_NAME = "HingeDevicesState"
        private const val SPEC_VERSION = 1
        private const val TAG = "hinge_devices"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val hingeSensor = HingeSensorSource(reactContext) { emitState() }
    private val displays = DisplaySource(reactContext)
    private val windowLayout = WindowLayoutSource { _, _, _ -> emitState() }

    private var listenerCount = 0
    private var angleUpdatesEnabled = false
    private var windowWidth = 0
    private var windowHeight = 0

    private var activeDisplayCache = "unknown"
    private var activeDisplayCacheKey = 0L

    init {
        reactContext.addLifecycleEventListener(this)
    }

    override fun getName(): String = NAME

    // --- Spec ---------------------------------------------------------------

    override fun getCapabilities(promise: Promise) {
        val map = Arguments.createMap().apply {
            val hasSensor = hingeSensor.isAvailable
            val hasFeature = windowLayout.hasSeenFeature
            putBoolean("isFoldable", hasSensor || hasFeature)
            putBoolean("hingeAngleSensor", hasSensor)
            putBoolean("foldingFeature", currentActivity != null)
            putBoolean("outerDisplay", displays.hasOuterDisplay())
            putBoolean("sceneAccessory", false)
            putBoolean("rearDisplayTransfer", false)
            putBoolean("dualConcurrent", false)
            putInt("specVersion", SPEC_VERSION)
            putString("manufacturer", Build.MANUFACTURER)
            putString("model", Build.MODEL)
        }
        promise.resolve(map)
    }

    override fun getDiagnostics(promise: Promise) {
        val map = Arguments.createMap().apply {
            putString("manufacturer", Build.MANUFACTURER)
            putString("model", Build.MODEL)
            putInt("sdkInt", Build.VERSION.SDK_INT)
            putString("activeDisplay", cachedActiveDisplay())
            putInt("windowWidth", windowWidth)
            putInt("windowHeight", windowHeight)

            for ((key, value) in hingeSensor.stats()) {
                when (value) {
                    is Int -> putInt(key, value)
                    is Boolean -> putBoolean(key, value)
                    is Double -> putDouble(key, value)
                    is List<*> -> putArray(key, Arguments.createArray().apply {
                        value.filterIsInstance<Double>().forEach(::pushDouble)
                    })
                    null -> putNull(key)
                    else -> putString(key, value.toString())
                }
            }
        }
        promise.resolve(map)
    }

    override fun setAngleUpdatesEnabled(enabled: Boolean) {
        angleUpdatesEnabled = enabled
        // Never stops the sensor: posture still needs it to tell a shut
        // device from an open one. Only the rate changes.
        if (listenerCount > 0) hingeSensor.start(fast = enabled)
    }

    override fun addListener(eventName: String) {
        listenerCount += 1
        if (listenerCount == 1) startSources()
        emitState()
    }

    override fun removeListeners(count: Double) {
        listenerCount = (listenerCount - count.toInt()).coerceAtLeast(0)
        if (listenerCount == 0) stopSources()
    }

    // --- Lifecycle ----------------------------------------------------------

    override fun onHostResume() {
        if (listenerCount > 0) startSources()
    }

    override fun onHostPause() {
        // A backgrounded app has no use for hinge readings, and a sensor left
        // registered across a pause is how a library gets blamed for battery.
        stopSources()
    }

    override fun onHostDestroy() {
        stopSources()
    }

    override fun invalidate() {
        reactContext.removeLifecycleEventListener(this)
        stopSources()
        super.invalidate()
    }

    private fun startSources() {
        hingeSensor.start(fast = angleUpdatesEnabled)
        currentActivity?.let(windowLayout::start)
    }

    private fun stopSources() {
        hingeSensor.stop()
        windowLayout.stop()
    }

    private val currentActivity: Activity?
        get() = reactContext.currentActivity

    // --- Emission -----------------------------------------------------------

    /**
     * Builds and delivers a state snapshot.
     *
     * Always hops to the main thread first. The hinge sensor calls back on the
     * sensor thread, and the window and display APIs this reads are not safe
     * to touch from there — doing so throws inside onSensorChanged and
     * silently kills every angle update, while main-thread window-layout
     * callbacks keep working and mask it.
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
            Log.w(TAG, "dropped a state update: ${error.message}")
        }
    }

    private fun buildAndSend() {
        if (listenerCount == 0 || !reactContext.hasActiveReactInstance()) return

        val metrics = reactContext.resources.displayMetrics
        val density = metrics.density
        windowWidth = metrics.widthPixels
        windowHeight = metrics.heightPixels
        val feature = windowLayout.lastFeature

        val payload: WritableMap = Arguments.createMap().apply {
            when (feature?.state) {
                FoldingFeature.State.FLAT -> putString("featureState", "flat")
                FoldingFeature.State.HALF_OPENED -> putString("featureState", "halfOpened")
                else -> putNull("featureState")
            }
            when (feature?.orientation) {
                FoldingFeature.Orientation.HORIZONTAL ->
                    putString("featureOrientation", "horizontal")
                FoldingFeature.Orientation.VERTICAL ->
                    putString("featureOrientation", "vertical")
                else -> putNull("featureOrientation")
            }

            val angle = hingeSensor.lastAngle
            if (angle == null) putNull("hingeAngle") else putDouble("hingeAngle", angle.toDouble())

            putString("activeDisplay", cachedActiveDisplay())
            putDouble("windowWidth", (windowWidth / density).toDouble())
            putDouble("windowHeight", (windowHeight / density).toDouble())

            if (feature != null) {
                putArray("features", Arguments.createArray().apply {
                    pushMap(Arguments.createMap().apply {
                        putDouble("left", (feature.bounds.left / density).toDouble())
                        putDouble("top", (feature.bounds.top / density).toDouble())
                        putDouble("right", (feature.bounds.right / density).toDouble())
                        putDouble("bottom", (feature.bounds.bottom / density).toDouble())
                        putBoolean("isSeparating", feature.isSeparating)
                        putString(
                            "occlusion",
                            when (feature.occlusionType) {
                                FoldingFeature.OcclusionType.FULL -> "full"
                                FoldingFeature.OcclusionType.NONE -> "none"
                                else -> "unknown"
                            },
                        )
                    })
                })
            }
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(EVENT_NAME, payload)
    }

    /**
     * Which display the app is on, recomputed only when the window resizes.
     *
     * Enumerating displays is not free, and the hinge sensor can fire many
     * times a second while an angle-driven effect is running.
     */
    private fun cachedActiveDisplay(): String {
        val key = windowWidth.toLong() shl 32 or windowHeight.toLong()
        if (key != activeDisplayCacheKey) {
            activeDisplayCacheKey = key
            activeDisplayCache = displays.activeDisplay(currentActivity)
        }
        return activeDisplayCache
    }
}
