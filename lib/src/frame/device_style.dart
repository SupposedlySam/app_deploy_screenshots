import 'dart:ui' show Color, Rect, Size;

import 'package:flutter/foundation.dart';

import '../../device.dart';

/// How the device is drawn in a `MarketingFrame`: bezel, corners, camera
/// cutout, shadow and any crop of the screen.
///
/// ```dart
/// device: DeviceStyle(),               // rounded bezel and shadow (default)
/// device: DeviceStyle.screenOnly(),    // floating screen, no bezel
/// device: DeviceStyle.detailed(),      // bezel plus Dynamic Island / punch-hole
/// device: DeviceStyle(crop: ScreenCrop.belowStatusBar),  // hide status bar
/// ```
///
/// Everything is drawn from plain shapes, so no manufacturer artwork is
/// involved.
@immutable
final class DeviceStyle {
  const DeviceStyle({
    this.bezel = const DeviceBezel(),
    this.cornerRadius,
    this.cutout = ScreenCutout.none,
    this.outline,
    this.glow,
    this.shadow = true,
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
  }) : assert(fadeOut >= 0 && fadeOut <= 1);

  /// The screen alone, with rounded corners and a shadow, and no bezel.
  const DeviceStyle.screenOnly({
    this.cornerRadius,
    this.outline,
    this.glow,
    this.shadow = true,
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
  }) : bezel = null,
       cutout = ScreenCutout.none,
       assert(fadeOut >= 0 && fadeOut <= 1);

  /// A bezel with the device's camera cutout (Dynamic Island, notch or
  /// punch-hole, chosen from the device), for a closer likeness to the phone.
  const DeviceStyle.detailed({
    this.bezel = const DeviceBezel(),
    this.cornerRadius,
    this.outline,
    this.glow,
    this.shadow = true,
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
  }) : cutout = ScreenCutout.auto,
       assert(fadeOut >= 0 && fadeOut <= 1);

  /// The frame around the screen, or null for none.
  final DeviceBezel? bezel;

  /// Screen corner radius in logical points. Defaults to
  /// `Device.screenCornerRadius`, or 16 when the device has none.
  final double? cornerRadius;

  /// Camera cutout drawn over the top of the screen.
  final ScreenCutout cutout;

  /// A thin line around the device (or the screen, without a bezel).
  final DeviceOutline? outline;

  /// A coloured glow around the device.
  final DeviceGlow? glow;

  /// A soft shadow under the device.
  final bool shadow;

  /// Part of the screenshot to leave out, e.g. the status bar.
  final ScreenCrop crop;

  /// Fades the bottom of the device into the background: the fraction of
  /// the device's height the fade covers, 0 for none.
  final double fadeOut;

  @override
  bool operator ==(Object other) =>
      other is DeviceStyle &&
      other.bezel == bezel &&
      other.cornerRadius == cornerRadius &&
      other.cutout == cutout &&
      other.outline == outline &&
      other.glow == glow &&
      other.shadow == shadow &&
      other.crop == crop &&
      other.fadeOut == fadeOut;

  @override
  int get hashCode => Object.hash(
    bezel,
    cornerRadius,
    cutout,
    outline,
    glow,
    shadow,
    crop,
    fadeOut,
  );
}

/// Plain rounded-rectangle device outline. No manufacturer artwork, so there
/// is nothing to license.
@immutable
final class DeviceBezel {
  const DeviceBezel({this.color = const Color(0xFF111111), this.width = 10});

  final Color color;

  /// Thickness in logical points.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is DeviceBezel && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

/// A line around the device.
@immutable
final class DeviceOutline {
  const DeviceOutline({this.color = const Color(0x33FFFFFF), this.width = 1.5});

  final Color color;

  /// Thickness in logical points.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is DeviceOutline && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

/// A soft coloured glow around the device.
@immutable
final class DeviceGlow {
  const DeviceGlow({required this.color, this.radius = 24});

  final Color color;

  /// Blur radius in logical points.
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is DeviceGlow && other.color == color && other.radius == radius;

  @override
  int get hashCode => Object.hash(color, radius);
}

/// The camera cutout drawn over the top of the screen.
@immutable
final class ScreenCutout {
  const ScreenCutout._(this._kind);

  /// No cutout.
  static const ScreenCutout none = ScreenCutout._(CutoutShape.none);

  /// Chosen from the device: a Dynamic Island on iPhones with a tall top
  /// inset, a notch on older notched iPhones, a punch-hole on Android
  /// phones, and nothing on tablets.
  static const ScreenCutout auto = ScreenCutout._(null);

  /// A Dynamic Island pill.
  static const ScreenCutout island = ScreenCutout._(CutoutShape.island);

  /// A notch across the top centre.
  static const ScreenCutout notch = ScreenCutout._(CutoutShape.notch);

  /// A round front camera hole.
  static const ScreenCutout punchHole = ScreenCutout._(CutoutShape.punchHole);

  final CutoutShape? _kind;

  /// The shape to draw on [device]. Not part of the public API.
  @internal
  CutoutShape shapeFor(Device device) {
    final kind = _kind;
    if (kind != null) return kind;
    if (device.size.shortestSide >= 600) return CutoutShape.none;
    if (device.platform == DevicePlatform.android) return CutoutShape.punchHole;
    final top = device.safeArea.top;
    if (top >= 59) return CutoutShape.island;
    if (top >= 44) return CutoutShape.notch;
    return CutoutShape.none;
  }

  @override
  String toString() => 'ScreenCutout.${_kind?.name ?? 'auto'}';
}

/// The cutout shapes the package draws. Internal to the package.
@internal
enum CutoutShape { none, island, notch, punchHole }

/// A part of the screenshot left out of the frame.
@immutable
final class ScreenCrop {
  const ScreenCrop._({
    this.top = 0,
    this.bottom = 0,
    this.statusBar = false,
    this.homeIndicator = false,
  });

  /// Show the whole screenshot.
  static const ScreenCrop none = ScreenCrop._();

  /// Leave out the status bar: the screen starts below the device's top
  /// safe-area inset. Most top listings hide the status bar this way.
  static const ScreenCrop belowStatusBar = ScreenCrop._(statusBar: true);

  /// Leave out the status bar and the home indicator area.
  static const ScreenCrop safeArea = ScreenCrop._(
    statusBar: true,
    homeIndicator: true,
  );

  /// Leave out [top] and [bottom] logical points.
  const ScreenCrop.points({double top = 0, double bottom = 0})
    : this._(top: top, bottom: bottom);

  final double top;
  final double bottom;
  final bool statusBar;
  final bool homeIndicator;

  /// The part of a screenshot of [imageSize] pixels, covering [viewRect] of
  /// [device]'s view, to show. Not part of the public API.
  @internal
  Rect sourceRectFor(Device device, Size imageSize, Rect viewRect) {
    final perPoint = imageSize.width / viewRect.width;
    // Insets apply only where the capture includes that edge of the screen.
    final insetTop = statusBar && viewRect.top <= 0 ? device.safeArea.top : 0;
    final insetBottom = homeIndicator ? device.safeArea.bottom : 0;
    final cutTop = ((top + insetTop) * perPoint).clamp(0, imageSize.height);
    final cutBottom = ((bottom + insetBottom) * perPoint).clamp(
      0,
      imageSize.height - cutTop,
    );
    return Rect.fromLTRB(
      0,
      cutTop.toDouble(),
      imageSize.width,
      imageSize.height - cutBottom,
    );
  }

  /// Whether the status bar area is left out.
  bool get hidesStatusBar => statusBar || top > 0;

  @override
  bool operator ==(Object other) =>
      other is ScreenCrop &&
      other.top == top &&
      other.bottom == bottom &&
      other.statusBar == statusBar &&
      other.homeIndicator == homeIndicator;

  @override
  int get hashCode => Object.hash(top, bottom, statusBar, homeIndicator);
}
