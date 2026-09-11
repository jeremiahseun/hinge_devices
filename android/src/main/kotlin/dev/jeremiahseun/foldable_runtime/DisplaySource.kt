package dev.jeremiahseun.foldable_runtime

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.Display

/**
 * Identifies which physical display the app currently occupies.
 *
 * Android has no API that says "this is the cover screen", so this compares
 * the app's display against every built-in display on the device: the largest
 * is the inner one, anything meaningfully smaller is a cover or outer screen.
 * The heuristic is deliberately shaped around what the platform actually
 * exposes rather than around any vendor's model names.
 */
internal class DisplaySource(private val context: Context) {

    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager

    /** Area in pixels of each built-in display, largest first. */
    private fun builtInAreas(): List<Long> {
        val displays = displayManager?.getDisplays(null) ?: return emptyList()
        return displays
            .filter { it.displayId == Display.DEFAULT_DISPLAY || isBuiltIn(it) }
            .map { display ->
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                display.getRealMetrics(metrics)
                metrics.widthPixels.toLong() * metrics.heightPixels.toLong()
            }
            .sortedDescending()
    }

    private fun isBuiltIn(display: Display): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            display.type == Display.TYPE_INTERNAL
        } else {
            @Suppress("DEPRECATION")
            display.type == Display.TYPE_BUILT_IN
        }
    }

    /** True when the device reports more than one built-in display. */
    fun hasOuterDisplay(): Boolean = builtInAreas().size > 1

    /**
     * Names the display [activity] is on.
     *
     * A device with a single display reports `unknown` rather than guessing
     * `inner`: on an ordinary phone the question is meaningless, and callers
     * check [FoldableCapabilities.outerDisplay] before they act on it.
     */
    fun activeDisplay(activity: Activity?): String {
        val areas = builtInAreas()
        if (activity == null || areas.size < 2) return "unknown"

        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            activity.windowManager.defaultDisplay
        } ?: return "unknown"

        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        val area = metrics.widthPixels.toLong() * metrics.heightPixels.toLong()
        val largest = areas.first()

        return when {
            area >= largest -> "inner"
            // A Flip-class Flex Window is a fraction of the inner display;
            // a Fold-class outer screen is a comparable size to it.
            area * 2 < largest -> "cover"
            else -> "outer"
        }
    }
}
