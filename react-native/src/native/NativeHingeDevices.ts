import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * The native contract, New Architecture only.
 *
 * Deliberately narrow and untyped at the boundary: the native side reports
 * *facts* — a folding feature, a sensor reading, window metrics — and every
 * derivation happens in TypeScript. That keeps the posture rules identical to
 * the Dart implementation and testable without a device, and it means a new
 * capability from a future platform arrives as an extra key rather than a
 * breaking change to this interface.
 */
export interface Spec extends TurboModule {
  /**
   * Reads capabilities once. Cached by the caller.
   *
   * Returns a flat object of booleans plus `specVersion`, `manufacturer` and
   * `model`.
   */
  getCapabilities(): Promise<Object>;

  /**
   * Reads live platform diagnostics — sensor event counts, distinct angles
   * seen, whether the hinge sweeps or only reports at detents.
   *
   * A call rather than a cached value on purpose: these are all about what
   * has happened since the app started.
   */
  getDiagnostics(): Promise<Object>;

  /**
   * Raises or lowers the hinge sensor's sampling rate.
   *
   * Never turns the sensor off: posture needs it to tell a shut device from
   * an open one. Opt-in because it is the only part of this package that can
   * measurably cost battery.
   */
  setAngleUpdatesEnabled(enabled: boolean): void;

  /** Required by NativeEventEmitter. */
  addListener(eventName: string): void;

  /** Required by NativeEventEmitter. */
  removeListeners(count: number): void;
}

/**
 * Resolved lazily and optionally.
 *
 * `get` rather than `getEnforcing`: this package must be safe to add to an
 * app that also builds for platforms with no native implementation, where it
 * reports a rigid device instead of throwing at import time.
 */
export default TurboModuleRegistry.get<Spec>('HingeDevices');
