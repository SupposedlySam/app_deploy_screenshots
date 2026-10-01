import 'package:flutter/foundation.dart';

/// Where the caption and the device sit on the canvas.
///
/// ```dart
/// layout: FrameLayout.captionTop,         // device fully inside, below
/// layout: FrameLayout.captionBottom,      // device above the caption
/// layout: FrameLayout.bleed(),            // device runs off the bottom
/// layout: FrameLayout.bleed(angle: -8),   // ...and is tilted
/// ```
@immutable
sealed class FrameLayout {
  const FrameLayout._();

  /// Caption above, the whole device below it.
  static const FrameLayout captionTop = _Stacked(captionFirst: true);

  /// The whole device above, caption below it.
  static const FrameLayout captionBottom = _Stacked(captionFirst: false);

  /// Caption above, a larger device rotated by `MarketingFrame.tilt`
  /// (default -8°), running off the bottom. The same as
  /// `FrameLayout.bleed(angle: -8)`, kept for 1.x code.
  static const FrameLayout tilted = _Bleed(width: 0.72, angle: null);

  /// Caption above, the device large and running off the bottom edge: the
  /// layout most top store listings use.
  ///
  /// [visible] is how much of the device's height stays on the canvas, so
  /// 0.9 cuts off the bottom 10%. The device is never wider than 94% of the
  /// canvas, which limits how much can be cut off when the canvas has the
  /// device's own shape (a phone on a phone canvas): there, more of it may
  /// show than asked. It always runs off the bottom edge.
  /// [angle] tilts it, in degrees (negative leans left).
  const factory FrameLayout.bleed({double visible, double angle}) =
      _Bleed.visible;

  /// How the geometry should place the device. Not part of the public API.
  @internal
  LayoutSpec get spec;
}

/// What [FrameLayout] tells the geometry. Internal to the package.
@internal
class LayoutSpec {
  const LayoutSpec({
    this.bleedWidth,
    this.bleedVisible,
    this.angle,
    this.captionFirst = true,
  });

  /// Whether the device runs off the bottom edge.
  bool get bleeds => bleedWidth != null || bleedVisible != null;

  /// The device's width as a fraction of the canvas.
  final double? bleedWidth;

  /// The fraction of the device's height left on the canvas.
  final double? bleedVisible;

  /// Rotation in degrees, or null to use `MarketingFrame.tilt`.
  final double? angle;

  /// Whether the caption comes before the device.
  final bool captionFirst;
}

class _Stacked extends FrameLayout {
  const _Stacked({required this.captionFirst}) : super._();

  final bool captionFirst;

  @override
  LayoutSpec get spec => LayoutSpec(angle: 0, captionFirst: captionFirst);

  @override
  bool operator ==(Object other) =>
      other is _Stacked && other.captionFirst == captionFirst;

  @override
  int get hashCode => captionFirst.hashCode;

  @override
  String toString() =>
      captionFirst ? 'FrameLayout.captionTop' : 'FrameLayout.captionBottom';
}

class _Bleed extends FrameLayout {
  const _Bleed({required double this.width, this.angle})
    : visible = null,
      super._();

  const _Bleed.visible({double this.visible = 0.9, double this.angle = 0})
    : assert(visible > 0 && visible <= 1),
      width = null,
      super._();

  final double? width;
  final double? visible;
  final double? angle;

  @override
  LayoutSpec get spec =>
      LayoutSpec(bleedWidth: width, bleedVisible: visible, angle: angle);

  @override
  bool operator ==(Object other) =>
      other is _Bleed &&
      other.width == width &&
      other.visible == visible &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(width, visible, angle);

  @override
  String toString() => angle == null
      ? 'FrameLayout.tilted'
      : 'FrameLayout.bleed(visible: $visible, angle: $angle)';
}
