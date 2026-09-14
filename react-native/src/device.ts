import { NativeEventEmitter } from 'react-native';

import NativeHingeDevices from './native/NativeHingeDevices';
import { DecodeContext, RawEvent, decodeCapabilities, decodeState } from './decode';
import { FoldableCapabilities, NO_CAPABILITIES } from './model/capabilities';
import { FoldableState, RIGID_DEVICE, sameLayout } from './model/state';
import {
  PostureThresholds,
  STANDARD_THRESHOLDS,
} from './model/resolver';
import { ASSUMED_QUIRK, HingeQuirk, lookupQuirk } from './model/quirks';

const EVENT_NAME = 'HingeDevicesState';

type Listener = (state: FoldableState) => void;

/**
 * The entry point to the foldable runtime.
 *
 * Safe on every device and every platform: without a native implementation it
 * reports a rigid device and emits nothing, so adding this package to an app
 * that will never run on a foldable cannot break it.
 */
class FoldableDeviceImpl {
  private listeners = new Set<Listener>();
  private emitter: NativeEventEmitter | null = null;
  private subscription: { remove(): void } | null = null;

  private capabilitiesPromise: Promise<FoldableCapabilities> | null = null;
  private capabilities: FoldableCapabilities = NO_CAPABILITIES;
  private quirk: HingeQuirk = ASSUMED_QUIRK;
  private thresholds: PostureThresholds = STANDARD_THRESHOLDS;

  private current: FoldableState | null = null;
  private override: FoldableState | null = null;
  private angleSubscribers = 0;

  /** The most recent state, or `null` before the first event. */
  get currentState(): FoldableState | null {
    return this.override ?? this.current;
  }

  /** Whether a native implementation is present on this platform. */
  get isSupported(): boolean {
    return NativeHingeDevices != null;
  }

  /** Whether angle updates are currently streaming. */
  get angleUpdatesEnabled(): boolean {
    return this.angleSubscribers > 0;
  }

  /** How many callers currently hold an angle-update request. */
  get angleSubscriberCount(): number {
    return this.angleSubscribers;
  }

  /**
   * Adjusts the angle thresholds used for the angle-only posture fallback.
   *
   * Call before the first subscription.
   */
  configureThresholds(thresholds: PostureThresholds): void {
    this.thresholds = thresholds;
  }

  /** The device's capabilities. Queried once and cached. */
  async getCapabilities(): Promise<FoldableCapabilities> {
    if (this.capabilitiesPromise) return this.capabilitiesPromise;

    const native = NativeHingeDevices;
    if (native == null) {
      this.capabilitiesPromise = Promise.resolve(NO_CAPABILITIES);
      return this.capabilitiesPromise;
    }

    this.capabilitiesPromise = native
      .getCapabilities()
      .then((reply) => {
        const raw = (reply ?? {}) as RawEvent;
        this.capabilities = decodeCapabilities(raw);
        this.quirk = lookupQuirk(
          typeof raw.manufacturer === 'string' ? raw.manufacturer : null,
          typeof raw.model === 'string' ? raw.model : null,
        );
        return this.capabilities;
      })
      .catch(() => NO_CAPABILITIES);

    return this.capabilitiesPromise;
  }

  /**
   * Reads live platform diagnostics.
   *
   * A call rather than a cached value: the useful numbers are all about what
   * has happened since the app started.
   */
  async getDiagnostics(): Promise<Record<string, unknown>> {
    const native = NativeHingeDevices;
    if (native == null) return {};
    try {
      return ((await native.getDiagnostics()) ?? {}) as Record<string, unknown>;
    } catch {
      return {};
    }
  }

  /**
   * Subscribes to device state. Returns an unsubscribe function.
   *
   * The listener is called immediately with the last known state when one
   * exists, so a component mounted after the device settled renders the right
   * layout on its first frame.
   */
  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    this.ensureListening();

    const seed = this.currentState;
    if (seed != null) listener(seed);

    return () => {
      this.listeners.delete(listener);
      if (this.listeners.size === 0) this.stopListening();
    };
  }

  /**
   * Raises the hinge sensor's sampling rate for angle-driven effects.
   *
   * Reference counted: two components can each enable updates and the first
   * one unmounting will not cut the sensor out from under the second. Pair
   * every call with exactly one {@link disableAngleUpdates}.
   */
  enableAngleUpdates(): void {
    this.angleSubscribers += 1;
    if (this.angleSubscribers > 1) return;
    NativeHingeDevices?.setAngleUpdatesEnabled(true);
  }

  /** Releases one angle-update request. */
  disableAngleUpdates(): void {
    if (this.angleSubscribers === 0) return;
    this.angleSubscribers -= 1;
    if (this.angleSubscribers > 0) return;
    NativeHingeDevices?.setAngleUpdatesEnabled(false);
  }

  /**
   * Forces a state for local development and tests.
   *
   * Wire this to a debug menu to exercise every posture without owning the
   * hardware. Pass `null` to hand control back to the platform.
   */
  debugOverride(state: FoldableState | null): void {
    this.override = state;
    const next = state ?? this.current;
    if (next != null) this.emit(next);
  }

  /** Drops all listeners and native subscriptions. Test-only. */
  resetForTesting(): void {
    this.stopListening();
    this.listeners.clear();
    this.capabilitiesPromise = null;
    this.capabilities = NO_CAPABILITIES;
    this.quirk = ASSUMED_QUIRK;
    this.thresholds = STANDARD_THRESHOLDS;
    this.current = null;
    this.override = null;
    this.angleSubscribers = 0;
  }

  private get decodeContext(): DecodeContext {
    return {
      quirk: this.quirk,
      capabilities: this.capabilities,
      thresholds: this.thresholds,
    };
  }

  private ensureListening(): void {
    if (this.subscription != null) return;

    const native = NativeHingeDevices;
    if (native == null) return;

    // Warm the capability cache without blocking: the decoder needs the
    // device's quirk entry and outer-display flag, but it has safe defaults
    // and self-corrects on the next event once capabilities resolve.
    void this.getCapabilities();

    this.emitter ??= new NativeEventEmitter(native as never);
    this.subscription = this.emitter.addListener(EVENT_NAME, (event) => {
      // The emitter types payloads as `Object`. Narrowing happens here, once,
      // rather than loosening the decoder's own types.
      this.onNativeEvent((event ?? {}) as RawEvent);
    });
  }

  private stopListening(): void {
    this.subscription?.remove();
    this.subscription = null;
  }

  private onNativeEvent(event: RawEvent): void {
    const { state, learnedOuterDisplay } = decodeState(
      event ?? {},
      this.decodeContext,
    );

    // Latch the deduction: a device does not grow or lose a panel.
    if (learnedOuterDisplay && !this.capabilities.outerDisplay) {
      this.capabilities = state.capabilities;
    }

    this.current = state;
    if (this.override != null) return;
    this.emit(state);
  }

  private emit(state: FoldableState): void {
    for (const listener of Array.from(this.listeners)) {
      listener(state);
    }
  }
}

/** The shared device instance. */
export const FoldableDevice = new FoldableDeviceImpl();

export { RIGID_DEVICE, sameLayout };
