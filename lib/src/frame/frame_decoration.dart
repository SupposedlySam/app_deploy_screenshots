import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Something placed on the frame's canvas: a logo, a rating badge, a
/// sticker, a row of integration icons.
///
/// ```dart
/// decorations: [
///   FrameDecoration.image(logoPng, alignment: Alignment.bottomCenter, width: 120),
///   FrameDecoration.widget(
///     const RatingBadge(stars: 4.8),
///     size: Size(160, 40),
///     alignment: Alignment.topCenter,
///     countsAsText: true,
///   ),
/// ],
/// ```
///
/// Positions are relative to the canvas inside its margins; sizes and
/// offsets are in caption points, so a decoration keeps its proportions on
/// every store size.
@immutable
sealed class FrameDecoration {
  const FrameDecoration({
    required this.alignment,
    required this.offset,
    required this.behindDevice,
  });

  /// An encoded image (PNG, JPEG, …), [width] caption points wide, its
  /// height following the image's shape.
  const factory FrameDecoration.image(
    Uint8List bytes, {
    double width,
    Alignment alignment,
    Offset offset,
    bool behindDevice,
  }) = ImageDecoration;

  /// Any widget, rendered at [size] caption points. It gets a `MediaQuery`,
  /// directionality and the default localizations, like a widget slide.
  ///
  /// Set [countsAsText] when it mostly holds text (a badge, a quote), so it
  /// counts toward the caption's share of the image in the Google Play
  /// check.
  const factory FrameDecoration.widget(
    Widget child, {
    required Size size,
    Alignment alignment,
    Offset offset,
    bool behindDevice,
    bool countsAsText,
  }) = WidgetDecoration;

  /// Where on the canvas, inside its margins.
  final Alignment alignment;

  /// Moves it from [alignment], in caption points.
  final Offset offset;

  /// Drawn under the device instead of over it.
  final bool behindDevice;
}

/// See [FrameDecoration.image].
final class ImageDecoration extends FrameDecoration {
  const ImageDecoration(
    this.bytes, {
    this.width = 80,
    super.alignment = Alignment.topCenter,
    super.offset = Offset.zero,
    super.behindDevice = false,
  });

  final Uint8List bytes;

  /// Width in caption points.
  final double width;
}

/// See [FrameDecoration.widget].
final class WidgetDecoration extends FrameDecoration {
  const WidgetDecoration(
    this.child, {
    required this.size,
    super.alignment = Alignment.topCenter,
    super.offset = Offset.zero,
    super.behindDevice = false,
    this.countsAsText = false,
  });

  final Widget child;

  /// Size in caption points.
  final Size size;

  /// Whether its area counts as text in the caption coverage check.
  final bool countsAsText;
}
