import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../variant.dart';

/// Chooses the frame for each screenshot, so a frame can vary by device,
/// locale and brightness.
///
/// A [MarketingFrame] is itself a [ScreenshotFrame] that always answers
/// itself. Use [ScreenshotFrame.builder] to localise captions or switch
/// backgrounds:
///
/// ```dart
/// frame: ScreenshotFrame.builder((context) => MarketingFrame(
///   background: FrameBackground.solid(
///     context.brightness == Brightness.dark ? Colors.black : Colors.white,
///   ),
///   caption: Caption(headline: headlines[context.locale.languageCode]!),
/// )),
/// ```
abstract interface class ScreenshotFrame {
  const factory ScreenshotFrame.builder(
    MarketingFrame? Function(ScreenshotContext context) builder,
  ) = _BuilderFrame;

  /// The frame to use for [context], or null for a plain screenshot.
  MarketingFrame? resolve(ScreenshotContext context);
}

class _BuilderFrame implements ScreenshotFrame {
  const _BuilderFrame(this._builder);
  final MarketingFrame? Function(ScreenshotContext context) _builder;

  @override
  MarketingFrame? resolve(ScreenshotContext context) => _builder(context);
}

/// Where the caption and the device sit on the canvas.
enum FrameLayout {
  /// Caption above, device below it.
  captionTop,

  /// Device above, caption below it.
  captionBottom,

  /// Caption above, device larger and rotated by `MarketingFrame.tilt`,
  /// running off the bottom of the canvas.
  tilted,
}

/// The canvas behind the device.
@immutable
sealed class FrameBackground {
  const FrameBackground();

  /// A single colour.
  const factory FrameBackground.solid(Color color) = _SolidBackground;

  /// A gradient filling the canvas, e.g. a [LinearGradient].
  const factory FrameBackground.gradient(Gradient gradient) =
      _GradientBackground;

  /// Encoded image bytes (PNG, JPEG, …) scaled to cover the canvas.
  ///
  /// Read them however suits the project: `File(path).readAsBytesSync()`
  /// or `(await rootBundle.load(asset)).buffer.asUint8List()`.
  const factory FrameBackground.image(Uint8List bytes, {Color fallback}) =
      _ImageBackground;

  /// Paints anything onto the canvas, in pixels.
  const factory FrameBackground.custom(
    void Function(Canvas canvas, Size size) paint, {
    Brightness brightness,
  }) = _CustomBackground;

  /// Whether text over this background should be dark or light.
  Brightness get brightness;

  /// Fills [size] with this background.
  @internal
  Future<void> fill(Canvas canvas, Size size) async {
    final rect = Offset.zero & size;
    switch (this) {
      case _SolidBackground(:final color):
        canvas.drawRect(rect, Paint()..color = color);
      case _GradientBackground(:final gradient):
        canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
      case _ImageBackground(:final bytes, :final fallback):
        canvas.drawRect(rect, Paint()..color = fallback);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final imageSize = Size(image.width.toDouble(), image.height.toDouble());
        final fitted = applyBoxFit(BoxFit.cover, imageSize, size);
        final src = Alignment.center.inscribe(
          fitted.source,
          Offset.zero & imageSize,
        );
        canvas.drawImageRect(
          image,
          src,
          rect,
          Paint()..filterQuality = FilterQuality.high,
        );
        image.dispose();
      case _CustomBackground(:final paint):
        paint(canvas, size);
    }
  }
}

class _SolidBackground extends FrameBackground {
  const _SolidBackground(this.color);
  final Color color;

  @override
  Brightness get brightness => _brightnessOf(color);
}

class _GradientBackground extends FrameBackground {
  const _GradientBackground(this.gradient);
  final Gradient gradient;

  @override
  Brightness get brightness {
    final colors = gradient.colors;
    final avg =
        colors.fold<double>(0, (s, c) => s + c.computeLuminance()) /
        colors.length;
    return avg > 0.45 ? Brightness.light : Brightness.dark;
  }
}

class _ImageBackground extends FrameBackground {
  const _ImageBackground(this.bytes, {this.fallback = const Color(0xFF202020)});
  final Uint8List bytes;

  /// Drawn under the image and used to choose the caption colour.
  final Color fallback;

  @override
  Brightness get brightness => _brightnessOf(fallback);
}

class _CustomBackground extends FrameBackground {
  const _CustomBackground(this.paint, {this.brightness = Brightness.light});
  final void Function(Canvas canvas, Size size) paint;

  @override
  final Brightness brightness;
}

Brightness _brightnessOf(Color c) =>
    c.computeLuminance() > 0.45 ? Brightness.light : Brightness.dark;

/// A headline and an optional subheadline.
///
/// Font sizes are in points of `MarketingFrame.referenceSize`, scaled by the
/// canvas area, so a caption covers the same share of every store image, from
/// a 1080 × 1920 phone to a 2064 × 2752 iPad.
@immutable
class Caption {
  const Caption({
    required this.headline,
    this.subheadline,
    this.headlineStyle,
    this.subheadlineStyle,
    this.textAlign = TextAlign.center,
    this.textDirection = TextDirection.ltr,
  });

  final String headline;
  final String? subheadline;

  /// Merged over 30pt bold Roboto in a colour that contrasts with the
  /// background. Set `fontFamily` to use one of the app's fonts.
  final TextStyle? headlineStyle;

  /// Merged over 17pt Roboto, slightly muted.
  final TextStyle? subheadlineStyle;

  final TextAlign textAlign;

  /// Set to [TextDirection.rtl] for right-to-left locales.
  final TextDirection textDirection;
}

/// Plain rounded-rectangle device outline. No manufacturer artwork, so there
/// is nothing to license.
@immutable
class DeviceBezel {
  const DeviceBezel({this.color = const Color(0xFF111111), this.width = 10});

  final Color color;

  /// Thickness in logical points.
  final double width;
}

/// Store-listing artwork: the screenshot scaled down onto a background, with
/// a caption, rounded corners and an optional bezel, at an exact pixel size.
///
/// The app is rendered at the device's logical size first, so layouts are
/// the real ones; only the finished image is scaled.
@immutable
class MarketingFrame implements ScreenshotFrame {
  const MarketingFrame({
    this.background = const FrameBackground.solid(Color(0xFFF2F2F7)),
    this.caption,
    this.layout = FrameLayout.captionTop,
    this.bezel = const DeviceBezel(),
    this.canvasSize,
    this.screenCornerRadius,
    this.tilt = -8,
    this.shadow = true,
    this.referenceSize = const Size(440, 956),
  });

  /// The canvas that caption sizes, margins and gaps are designed for, in
  /// points. The default is a 6.9" iPhone.
  ///
  /// On a canvas of a different size every one of them is scaled by
  /// `sqrt(canvas area / reference area)`, so text covers the same share of
  /// the image. Store listings show screenshots at similar sizes whatever the
  /// device, so a caption set in device points would shrink on tablets.
  final Size referenceSize;

  final FrameBackground background;
  final Caption? caption;
  final FrameLayout layout;

  /// Null draws the screen with rounded corners and no outline.
  final DeviceBezel? bezel;

  /// Output size in pixels. Defaults to the device's full-screen pixel size,
  /// so a store preset device produces an upload-ready image. Set this to
  /// show one device on a different store's canvas, e.g. a 20:9 phone on
  /// Google Play's 1080 × 1920.
  final Size? canvasSize;

  /// Screen corner radius in logical points. Defaults to
  /// `Device.screenCornerRadius`, or 16 when the device has none.
  final double? screenCornerRadius;

  /// Rotation in degrees for [FrameLayout.tilted].
  final double tilt;

  /// Soft shadow under the device.
  final bool shadow;

  @override
  MarketingFrame resolve(ScreenshotContext context) => this;
}
