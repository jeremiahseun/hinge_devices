package dev.jeremiahseun.foldable_runtime

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build

/**
 * Wraps [Sensor.TYPE_HINGE_ANGLE], available since API 30.
 *
 * Registered at two rates. Posture only needs to know when the hinge settles,
 * so the default is [SensorManager.SENSOR_DELAY_NORMAL]. Angle-driven effects
 * need every intermediate reading, so enabling angle updates re-registers at
 * [SensorManager.SENSOR_DELAY_GAME]. Running at the fast rate all the time
 * would be the one part of this package that could be blamed for battery.
 */
internal class HingeSensorSource(
    context: Context,
    private val onAngle: (Float?) -> Unit,
) : SensorEventListener {

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private val sensor: Sensor? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            sensorManager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)
        } else {
            null
        }

    /** Whether this device exposes a hinge-angle sensor at all. */
    val isAvailable: Boolean get() = sensor != null

    /**
     * The last reading, or null when the sensor is not currently delivering.
     *
     * Deliberately cleared on [stop]. A reading held across an unregister is
     * stale by definition, and a stale "0" is indistinguishable from a device
     * that is genuinely shut — which is how an opened Flip ends up rendering
     * its closed layout.
     */
    var lastAngle: Float? = null
        private set

    /** Total readings delivered since attach. Surfaced for device reports. */
    var eventCount: Int = 0
        private set

    private var registered = false
    private var fastRate = false

    /** Registers the sensor, or re-registers it when the rate changes. */
    fun start(fast: Boolean = false) {
        val manager = sensorManager ?: return
        val hinge = sensor ?: return
        if (registered && fast == fastRate) return
        if (registered) manager.unregisterListener(this)

        fastRate = fast
        val delay = if (fast) {
            SensorManager.SENSOR_DELAY_GAME
        } else {
            SensorManager.SENSOR_DELAY_NORMAL
        }
        // An on-change sensor re-delivers its current value on registration,
        // so lastAngle repopulates without waiting for the user to move it.
        registered = manager.registerListener(this, hinge, delay)
    }

    fun stop() {
        if (!registered) return
        sensorManager?.unregisterListener(this)
        registered = false
        lastAngle = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val value = event?.values?.firstOrNull() ?: return
        lastAngle = value
        eventCount++
        onAngle(value)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
