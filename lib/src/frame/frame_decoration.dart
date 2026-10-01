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
    required this.countsAsText,
  });

  /// An encoded image (PNG, JPEG, …), [width] caption points wide, its
  /// height following the image's shape.
  const factory FrameDecoration.image(
    Uint8List bytes, {
    double width,
    Alignment alignment,
    Offset offset,
    bool behindDevice,
    bool countsAsText,
  }) = ImageDecoration;

  /// Any widget, rendered at [size] caption points. It gets a `MediaQuery`,
  /// text direction from the locale, the default (English) localizations
  /// and a `Theme` in the screenshot's brightness. Animations are drawn at
  /// their first frame.
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

  /// Set when it mostly holds text (a rating badge, a wordmark, a quote),
  /// so its area counts toward the caption's share of the image in the
  /// Google Play check.
  final bool countsAsText;
}

/// See [FrameDecoration.image].
final class ImageDecoration extends FrameDecoration {
  const ImageDecoration(
    this.bytes, {
    this.width = 80,
    super.alignment = Alignment.topCenter,
    super.offset = Offset.zero,
    super.behindDevice = false,
    super.countsAsText = false,
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
    super.countsAsText = false,
  });

  final Widget child;

  /// Size in caption points.
  final Size size;
}
