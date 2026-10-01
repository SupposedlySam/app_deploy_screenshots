// ignore_for_file: deprecated_member_use_from_same_package

import 'device_style.dart';
import 'marketing_frame.dart';

/// What a frame resolves to once the deprecated 1.x parameters are folded
/// in. Internal: not exported, so it stays out of users' autocomplete.
extension FrameResolution on MarketingFrame {
  /// The device style in effect: `device`, or one built from the 1.x
  /// `bezel`, `screenCornerRadius` and `shadow` parameters.
  DeviceStyle get effectiveDevice =>
      device ??
      DeviceStyle(
        bezel: bezel,
        cornerRadius: screenCornerRadius,
        shadow: shadow ? const DeviceShadow() : null,
      );

  /// The tilt in effect for the layout, in degrees.
  double get effectiveAngle => layout.spec.angle ?? tilt;
}
