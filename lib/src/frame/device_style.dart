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
    this.shadow = const DeviceShadow(),
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
    this.buttons = false,
  }) : assert(fadeOut >= 0 && fadeOut <= 1);

  /// The screen alone: no bezel by default. Every option is still
  /// available, e.g. `DeviceStyle.screenOnly(cutout: ScreenCutout.island)`.
  const DeviceStyle.screenOnly({
    this.bezel,
    this.cornerRadius,
    this.cutout = ScreenCutout.none,
    this.outline,
    this.glow,
    this.shadow = const DeviceShadow(),
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
    this.buttons = false,
  }) : assert(fadeOut >= 0 && fadeOut <= 1);

  /// A bezel with the device's camera cutout (Dynamic Island, notch or
  /// punch-hole, chosen from the device) and side buttons, for a closer
  /// likeness to the phone. Every option is still available.
  const DeviceStyle.detailed({
    this.bezel = const DeviceBezel(),
    this.cornerRadius,
    this.cutout = ScreenCutout.auto,
    this.outline,
    this.glow,
    this.shadow = const DeviceShadow(),
    this.crop = ScreenCrop.none,
    this.fadeOut = 0,
    this.buttons = true,
  }) : assert(fadeOut >= 0 && fadeOut <= 1);

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

  /// The shadow under the device, or null for none.
  final DeviceShadow? shadow;

  /// Part of the screenshot to leave out, e.g. the status bar.
  final ScreenCrop crop;

  /// Fades the bottom of the device into the background: the fraction of
  /// the device's height the fade covers, 0 for none.
  final double fadeOut;

  /// Side buttons drawn on the bezel's edges: power and volume, placed for
  /// the device's platform. Needs a [bezel].
  final bool buttons;

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
      other.fadeOut == fadeOut &&
      other.buttons == buttons;

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
    buttons,
  );
}

/// Plain rounded-rectangle device outline. No manufacturer artwork, so there
/// is nothing to license.
@immutable
class DeviceBezel {
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

/// A soft shadow under the device.
@immutable
final class DeviceShadow {
  const DeviceShadow({
    this.color = const Color(0x40000000),
    this.blur = 18,
    this.offset = 12,
  });

  final Color color;

  /// Blur radius, in caption points.
  final double blur;

  /// How far below the device the shadow falls, in caption points.
  final double offset;

  @override
  bool operator ==(Object other) =>
      other is DeviceShadow &&
      other.color == color &&
      other.blur == blur &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(color, blur, offset);
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
    double top = 0,
    double bottom = 0,
    bool statusBar = false,
    bool homeIndicator = false,
  }) : _top = top,
       _bottom = bottom,
       _statusBar = statusBar,
       _homeIndicator = homeIndicator;

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

  final double _top;
  final double _bottom;
  final bool _statusBar;
  final bool _homeIndicator;

  /// The part of a screenshot of [imageSize] pixels, covering [viewRect] of
  /// [device]'s view, to show. Not part of the public API.
  @internal
  Rect sourceRectFor(Device device, Size imageSize, Rect viewRect) {
    final perPoint = imageSize.width / viewRect.width;
    // Insets apply only where the capture includes that edge of the screen.
    final insetTop = _statusBar && viewRect.top <= 0 ? device.safeArea.top : 0;
    final insetBottom = _homeIndicator ? device.safeArea.bottom : 0;
    final cutTop = ((_top + insetTop) * perPoint).clamp(0, imageSize.height);
    final cutBottom = ((_bottom + insetBottom) * perPoint).clamp(
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

  /// Whether the crop leaves out [device]'s whole status bar area. Not
  /// part of the public API.
  @internal
  bool hidesStatusBarOn(Device device) =>
      _statusBar || (device.safeArea.top > 0 && _top >= device.safeArea.top);

  @override
  bool operator ==(Object other) =>
      other is ScreenCrop &&
      other._top == _top &&
      other._bottom == _bottom &&
      other._statusBar == _statusBar &&
      other._homeIndicator == _homeIndicator;

  @override
  int get hashCode => Object.hash(_top, _bottom, _statusBar, _homeIndicator);
}
