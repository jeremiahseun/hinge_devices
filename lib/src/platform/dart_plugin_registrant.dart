import 'hinge_devices_platform.dart';

/// The Dart-only plugin implementation used on every platform without native
/// foldable support.
///
/// Its existence is what lets this package declare iOS, macOS, Windows and
/// Linux support in `pubspec.yaml`. Without it the package reads as
/// Android-only on pub.dev, and a developer whose app also targets iOS
/// filters it out — even though adding it to that app is completely safe and
/// reports a rigid device.
///
/// [registerWith] is intentionally empty: [HingeDevicesPlatform] selects
/// [UnsupportedHingeDevices] by target platform already, so there is
/// nothing to wire up. It exists because Flutter's tooling requires a
/// registrant with this shape.
class HingeDevicesDartPlugin {
  /// Called by Flutter's generated plugin registrant.
  static void registerWith() {
    // Nothing to register. See the class docs.
  }
}
