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
 * The sensor is an on-change sensor, so it only fires when the hinge actually
 * moves. It is still registered lazily and unregistered whenever the host
 * activity is not resumed — a sensor left registered across a backgrounded app
 * is the classic way a library gets blamed for battery drain.
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

    /** The last reading, or null if the sensor has never fired. */
    var lastAngle: Float? = null
        private set

    private var registered = false

    fun start() {
        val manager = sensorManager ?: return
        val hinge = sensor ?: return
        if (registered) return
        registered = manager.registerListener(
            this,
            hinge,
            SensorManager.SENSOR_DELAY_UI,
        )
    }

    fun stop() {
        if (!registered) return
        sensorManager?.unregisterListener(this)
        registered = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val value = event?.values?.firstOrNull() ?: return
        lastAngle = value
        onAngle(value)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
