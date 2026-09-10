package dev.jeremiahseun.foldable_runtime

import android.app.Activity
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * Observes [WindowLayoutInfo] for folding-feature geometry.
 *
 * Note this reports state, orientation, occlusion and bounds — but *not* the
 * hinge angle. Angle comes from [HingeSensorSource]; the two are independent
 * signals with independent availability, and a device may expose either one
 * without the other.
 */
internal class WindowLayoutSource(
    private val onLayout: (FoldingFeature?, Int, Int) -> Unit,
) {
    private var job: Job? = null
    private var scope: CoroutineScope? = null

    /** The most recent folding feature, or null when none is reported. */
    var lastFeature: FoldingFeature? = null
        private set

    /** True once a folding feature has ever been observed. */
    var hasSeenFeature: Boolean = false
        private set

    fun start(activity: Activity) {
        stop()
        val newScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        scope = newScope
        job = newScope.launch {
            runCatching {
                WindowInfoTracker.getOrCreate(activity)
                    .windowLayoutInfo(activity)
                    .collectLatest { info -> emit(activity, info) }
            }
        }
    }

    private fun emit(activity: Activity, info: WindowLayoutInfo) {
        val feature = info.displayFeatures
            .filterIsInstance<FoldingFeature>()
            .firstOrNull()
        lastFeature = feature
        if (feature != null) hasSeenFeature = true

        val metrics = activity.resources.displayMetrics
        onLayout(feature, metrics.widthPixels, metrics.heightPixels)
    }

    fun stop() {
        job?.cancel()
        job = null
        scope = null
    }
}
