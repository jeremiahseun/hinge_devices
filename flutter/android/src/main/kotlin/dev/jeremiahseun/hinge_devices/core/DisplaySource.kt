// GENERATED FILE — DO NOT EDIT.
//
// Vendored from core-android/. Edit the file there, then run:
//     dart run tool/sync_shared.dart
package dev.jeremiahseun.hinge_devices.core

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.Display

/**
 * Reports which physical display the app currently occupies.
 *
 * Android has no public API that says "this is the cover screen".
 * `Display.getType()` and the `TYPE_INTERNAL` constants are hidden API, and
 * reflecting onto them is blocked from Android 9 onward — it fails silently
 * and every display comes back as "not built in", which is worse than not
 * asking. So this uses only public signals:
 *
 *  - [Display.FLAG_PRESENTATION] and [Display.FLAG_PRIVATE] exclude virtual,
 *    cast and presentation displays.
 *  - The app's own window is compared against the largest display area seen
 *    on this device so far.
 *
 * On Flip-class hardware the cover and inner panels are frequently the *same*
 * logical display that simply resizes, so display enumeration alone can never
 * detect the cover screen. The size comparison is what actually works there,
 * and it needs a baseline — until one exists this reports `unknown` rather
 * than guessing.
 *
 * None of this feeds posture. Posture comes from the folding feature and the
 * hinge angle, both of which are real APIs; a heuristic must not be able to
 * put a device on the wrong layout.
 */
class DisplaySource(private val context: Context) {

    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager

    /** The largest window area observed so far, in pixels. */
    private var largestAreaSeen: Long = 0

    /** Areas of every display that looks like a physical panel, largest first. */
    private fun physicalDisplayAreas(): List<Long> {
        val displays = displayManager?.getDisplays(null) ?: return emptyList()
        return displays
            .filter { it.displayId == Display.DEFAULT_DISPLAY || isPhysical(it) }
            .map(::areaOf)
            .filter { it > 0 }
            .sortedDescending()
    }

    // Public flags only. A display that is private or exists to be presented
    // onto is not a panel the user folds.
    private fun isPhysical(display: Display): Boolean {
        val flags = display.flags
        val isPresentation = flags and Display.FLAG_PRESENTATION != 0
        val isPrivate = flags and Display.FLAG_PRIVATE != 0
        return !isPresentation && !isPrivate
    }

    private fun areaOf(display: Display): Long {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        return metrics.widthPixels.toLong() * metrics.heightPixels.toLong()
    }

    /**
     * True when the device looks like it has more than one physical panel.
     *
     * Two independent signals, either of which is sufficient: the platform
     * enumerates more than one panel, or this app has rendered at two clearly
     * different sizes on the same device.
     */
    fun hasOuterDisplay(): Boolean =
        physicalDisplayAreas().size > 1 || sawTwoDistinctSizes

    private var sawTwoDistinctSizes = false

    /**
     * Names the display [activity] is on.
     *
     * Returns `unknown` freely — on an ordinary phone the question is
     * meaningless, and on the first launch of a Flip there is no baseline to
     * compare against yet.
     */
    fun activeDisplay(activity: Activity?): String {
        if (activity == null) return "unknown"

        val display = currentDisplay(activity) ?: return "unknown"
        val area = areaOf(display)
        if (area <= 0) return "unknown"

        val enumeratedLargest = physicalDisplayAreas().firstOrNull() ?: 0
        val largest = maxOf(largestAreaSeen, enumeratedLargest, area)
        if (largest > largestAreaSeen) largestAreaSeen = largest

        // Within a tenth of the largest panel: this is the main display.
        if (area * 10 >= largest * 9) {
            return if (largest > 0 && hasOuterDisplay()) "inner" else "unknown"
        }

        sawTwoDistinctSizes = true

        // A Flip-class Flex Window is a fraction of the inner panel; a
        // Fold-class outer screen is a whole phone screen in its own right.
        return if (area * 2 < largest) "cover" else "outer"
    }

    private fun currentDisplay(activity: Activity): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay
        }
    }
}
