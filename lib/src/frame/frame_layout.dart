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

  /// The 1.x tilted layout, kept for 1.x code: caption above, the device
  /// right under it at 0.72 of the canvas width, rotated by
  /// `MarketingFrame.tilt` (default -8°). For new code,
  /// `FrameLayout.bleed(angle: -8)` runs a larger tilted device off the
  /// bottom edge, as top listings do.
  static const FrameLayout tilted = _Bleed._tilted();

  /// Caption above, the device large and running off the bottom edge: the
  /// layout most top store listings use.
  ///
  /// * [width] is the device's width, bezel included, as a fraction of the
  ///   canvas: 0.86 by default, 0.78 when tilted so the corners stay on the
  ///   canvas.
  /// * [visible] is how much of the device's height stays on the canvas:
  ///   0.8 cuts off the bottom fifth. The device moves down to hide the
  ///   rest; if that would run it into the caption, it is drawn smaller.
  /// * [angle] tilts it, in degrees (negative leans left).
  const factory FrameLayout.bleed({
    double? width,
    double visible,
    double angle,
  }) = _Bleed;

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
  bool get bleeds => bleedWidth != null;

  /// The device's width as a fraction of the canvas, when it bleeds.
  final double? bleedWidth;

  /// The fraction of the device's height left on the canvas, or null to
  /// place it right under the caption.
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
  const _Bleed({this.width, double this.visible = 0.8, double this.angle = 0})
    : assert(width == null || (width > 0 && width <= 1.5)),
      assert(visible > 0 && visible <= 1),
      super._();

  /// The 1.x tilted layout: the device sits right under the caption.
  const _Bleed._tilted()
    : width = 0.72,
      visible = null,
      angle = null,
      super._();

  final double? width;
  final double? visible;
  final double? angle;

  @override
  LayoutSpec get spec => LayoutSpec(
    bleedWidth: width ?? (angle == 0 ? 0.86 : 0.78),
    bleedVisible: visible,
    angle: angle,
  );

  @override
  bool operator ==(Object other) =>
      other is _Bleed &&
      other.width == width &&
      other.visible == visible &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(width, visible, angle);

  @override
  String toString() => visible == null
      ? 'FrameLayout.tilted'
      : 'FrameLayout.bleed(width: $width, visible: $visible, angle: $angle)';
}
