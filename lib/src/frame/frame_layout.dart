// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/foundation.dart';

/// Where the caption and the device sit on the canvas: the 1.x enum.
///
/// It can't take options, so a device running off the bottom edge is added
/// beside it with `MarketingFrame(bleed: FrameBleed(...))`. Prefer
/// `MarketingFrame(slideLayout: SlideLayout...)`, which replaces both:
///
/// ```dart
/// // 1.x style, deprecated:
/// MarketingFrame(layout: FrameLayout.captionTop, bleed: FrameBleed(angle: -8))
/// // Current:
/// MarketingFrame(slideLayout: SlideLayout.bleed(angle: -8))
/// ```
@Deprecated(
  'Use MarketingFrame(slideLayout: SlideLayout.captionTop / .captionBottom '
  '/ .bleed(...)). Removed in 2.0.',
)
enum FrameLayout {
  /// Caption above, device below it.
  captionTop,

  /// Device above, caption below it.
  captionBottom,

  /// Caption above, the device right under it at 0.72 of the canvas width,
  /// rotated by `MarketingFrame.tilt` (default -8°).
  tilted,
}

/// A device running off the bottom edge, for 1.x-style frames that set
/// [FrameLayout]: `MarketingFrame(bleed: FrameBleed(angle: -8))`. When set,
/// it replaces the frame's `layout`. Same options as [SlideLayout.bleed].
@Deprecated(
  'Use MarketingFrame(slideLayout: SlideLayout.bleed(...)). '
  'Removed in 2.0.',
)
@immutable
class FrameBleed {
  const FrameBleed({this.width, this.visible = 0.8, this.angle = 0})
    : assert(width == null || (width > 0 && width <= 1.5)),
      assert(visible > 0 && visible <= 1);

  /// See [SlideLayout.bleed].
  final double? width;

  /// See [SlideLayout.bleed].
  final double visible;

  /// See [SlideLayout.bleed].
  final double angle;

  /// The same layout as a [SlideLayout].
  SlideLayout toSlideLayout() =>
      SlideLayout.bleed(width: width, visible: visible, angle: angle);

  @override
  bool operator ==(Object other) =>
      other is FrameBleed &&
      other.width == width &&
      other.visible == visible &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(width, visible, angle);
}

/// The [SlideLayout] each 1.x [FrameLayout] value draws. Internal.
@internal
extension FrameLayoutSlide on FrameLayout {
  SlideLayout get slideLayout => switch (this) {
    FrameLayout.captionTop => SlideLayout.captionTop,
    FrameLayout.captionBottom => SlideLayout.captionBottom,
    FrameLayout.tilted => const _Bleed._tilted(),
  };
}

/// Where the caption and the device sit on the canvas.
///
/// ```dart
/// slideLayout: SlideLayout.captionTop,        // device fully inside, below
/// slideLayout: SlideLayout.captionBottom,     // device above the caption
/// slideLayout: SlideLayout.bleed(),           // device runs off the bottom
/// slideLayout: SlideLayout.bleed(angle: -8),  // ...and is tilted
/// ```
@immutable
sealed class SlideLayout {
  const SlideLayout._();

  /// Caption above, the whole device below it.
  static const SlideLayout captionTop = _Stacked(captionFirst: true);

  /// The whole device above, caption below it.
  static const SlideLayout captionBottom = _Stacked(captionFirst: false);

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
  const factory SlideLayout.bleed({
    double? width,
    double visible,
    double angle,
  }) = _Bleed;

  /// How the geometry should place the device. Not part of the public API.
  @internal
  LayoutSpec get spec;
}

/// What a [SlideLayout] tells the geometry. Internal to the package.
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

class _Stacked extends SlideLayout {
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
      captionFirst ? 'SlideLayout.captionTop' : 'SlideLayout.captionBottom';
}

class _Bleed extends SlideLayout {
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
      : 'SlideLayout.bleed(width: $width, visible: $visible, angle: $angle)';
}
