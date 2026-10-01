import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Something drawn over a screenshot, positioned by a [Finder] so it follows
/// the widget on every device size.
///
/// The finder is evaluated after the device's overrides and pumps, and must
/// match at least one widget; the first match is used. A finder that matches
/// nothing throws rather than producing a screenshot with the annotation
/// silently missing.
@immutable
sealed class ScreenshotAnnotation {
  const ScreenshotAnnotation(this.target);

  /// The widget the annotation points at.
  final Finder target;
}

/// Dims everything except [target], drawing the eye to it.
///
/// Several spotlights on one screenshot share a single scrim, each cutting
/// its own hole.
class Spotlight extends ScreenshotAnnotation {
  const Spotlight(
    super.target, {
    this.padding = const EdgeInsets.all(8),
    this.radius = 12,
    this.scrim = const Color(0x99000000),
  });

  /// Space between the widget's bounds and the edge of the hole, in logical
  /// points.
  final EdgeInsets padding;

  /// Corner radius of the hole, in logical points.
  final double radius;

  /// Colour laid over everything outside the hole.
  final Color scrim;
}

/// Where a [Callout] bubble sits relative to its target.
enum CalloutPlacement {
  /// Above the target when it is in the lower half of the screen, else below.
  auto,
  above,
  below,
}

/// A speech bubble with [text] and an arrow pointing at [target].
class Callout extends ScreenshotAnnotation {
  const Callout(
    super.target,
    this.text, {
    this.placement = CalloutPlacement.auto,
    this.style,
    this.color = const Color(0xFF1C1C1E),
    this.maxWidth = 260,
  });

  final String text;
  final CalloutPlacement placement;

  /// Text style in logical points. Defaults to 15pt white Roboto.
  final TextStyle? style;

  /// Bubble fill.
  final Color color;

  /// Widest the bubble may grow before the text wraps, in logical points.
  final double maxWidth;
}

/// Lifts [target] out of the screen: the same pixels, drawn in place a
/// little larger with a drop shadow, so a card or row seems to pop off the
/// device. The most common way top store listings point at a feature.
///
/// Inside a `MarketingFrame` the lifted widget is drawn on the canvas, so it
/// can extend past the device's edges, and it turns with a tilted device.
final class Lift extends ScreenshotAnnotation {
  const Lift(
    super.target, {
    this.scale = 1.08,
    this.radius = 12,
    this.padding = EdgeInsets.zero,
    this.elevation = 16,
  }) : assert(scale > 0),
       assert(elevation >= 0);

  /// How much larger than on screen. 1 keeps its size and only adds the
  /// shadow.
  final double scale;

  /// Corner radius of the lifted piece, in logical points.
  final double radius;

  /// Extra area around the target to lift with it, in logical points.
  final EdgeInsets padding;

  /// Shadow depth, in logical points. 0 for no shadow.
  final double elevation;
}

/// The shape of a [MagnifierInset] inset.
enum MagnifierShape { circle, roundedRect }

/// Enlarges [target] into an inset drawn over the screenshot, e.g. to make
/// one message row legible in a store listing.
///
/// Inside a `MarketingFrame` the inset is drawn on the canvas at full canvas
/// resolution, centred on the target, so a wide inset can extend past the
/// edges of the device. Without a frame it is kept inside the screenshot.
class MagnifierInset extends ScreenshotAnnotation {
  const MagnifierInset(
    super.target, {
    this.zoom = 1.4,
    this.shape = MagnifierShape.roundedRect,
    this.padding = const EdgeInsets.all(4),
    this.offset = Offset.zero,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 3,
    this.radius = 16,
  }) : assert(zoom > 0);

  /// How much larger than on screen, relative to the device.
  final double zoom;
  final MagnifierShape shape;

  /// Extra area around the target to include, in logical points.
  final EdgeInsets padding;

  /// Moves the inset from its default position, in logical points.
  final Offset offset;

  final Color borderColor;

  /// Border width, in logical points.
  final double borderWidth;

  /// Corner radius for [MagnifierShape.roundedRect], in logical points.
  final double radius;
}

/// An annotation together with where its target was on screen, in the
/// view's logical coordinates.
@immutable
class ResolvedAnnotation {
  const ResolvedAnnotation(this.annotation, this.rect);

  final ScreenshotAnnotation annotation;
  final Rect rect;
}
