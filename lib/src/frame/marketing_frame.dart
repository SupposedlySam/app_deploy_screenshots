// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../variant.dart';
import 'caption.dart';
import 'device_style.dart';
import 'frame_decoration.dart';
import 'frame_layout.dart';

export 'caption.dart' show Caption;
export 'device_style.dart' show DeviceBezel;
export 'frame_layout.dart' show FrameLayout, FrameBleed, SlideLayout;

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
  ///
  /// [blur] softens it, in caption points, so a photo sets a mood without
  /// competing with the caption. [tint] is laid over it, e.g. a translucent
  /// black to keep white text readable. [fallback] is drawn underneath and
  /// decides whether the caption is dark or light: pick a colour close to
  /// the image's overall tone.
  const factory FrameBackground.image(
    Uint8List bytes, {
    Color fallback,
    double blur,
    Color? tint,
  }) = _ImageBackground;

  /// The app's own screen, enlarged to cover the canvas, blurred and
  /// tinted: a backdrop that always matches the screenshot. On a slide
  /// without a device, [fallback] fills the canvas instead.
  ///
  /// [brightness] says whether the result is dark or light, which sets the
  /// caption colour; the default dark tint suits white captions.
  const factory FrameBackground.screen({
    double blur,
    Color tint,
    Color fallback,
    Brightness brightness,
  }) = _ScreenBackground;

  /// Paints anything onto the canvas, in pixels.
  const factory FrameBackground.custom(
    void Function(Canvas canvas, Size size) paint, {
    Brightness brightness,
  }) = _CustomBackground;

  /// Whether text over this background should be dark or light.
  Brightness get brightness;

  /// Fills [size] with this background. [unit] is canvas pixels per caption
  /// point; [screen] is the screenshot on this slide, if there is one.
  @internal
  Future<void> fill(
    Canvas canvas,
    Size size, {
    double unit = 1,
    ui.Image? screen,
  }) async {
    final rect = Offset.zero & size;
    switch (this) {
      case _SolidBackground(:final color):
        canvas.drawRect(rect, Paint()..color = color);
      case _GradientBackground(:final gradient):
        canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
      case _ImageBackground(
        :final bytes,
        :final fallback,
        :final blur,
        :final tint,
      ):
        canvas.drawRect(rect, Paint()..color = fallback);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        _cover(canvas, image, rect, blur * unit);
        image.dispose();
        if (tint != null) canvas.drawRect(rect, Paint()..color = tint);
      case _ScreenBackground(:final blur, :final tint, :final fallback):
        canvas.drawRect(rect, Paint()..color = fallback);
        if (screen != null) _cover(canvas, screen, rect, blur * unit);
        canvas.drawRect(rect, Paint()..color = tint);
      case _CustomBackground(:final paint):
        paint(canvas, size);
    }
  }
}

/// Draws [image] to cover [rect], blurred by [sigma] canvas pixels.
void _cover(Canvas canvas, ui.Image image, Rect rect, double sigma) {
  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(BoxFit.cover, imageSize, rect.size);
  final src = Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
  final paint = Paint()..filterQuality = FilterQuality.high;
  if (sigma <= 0) {
    canvas.drawImageRect(image, src, rect, paint);
    return;
  }
  // Clamp the blur at the edges, or it fades to transparent there.
  canvas
    ..save()
    ..clipRect(rect)
    ..saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    )
    ..drawImageRect(image, src, rect, paint)
    ..restore()
    ..restore();
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
  const _ImageBackground(
    this.bytes, {
    this.fallback = const Color(0xFF202020),
    this.blur = 0,
    this.tint,
  }) : assert(blur >= 0);
  final Uint8List bytes;
  final double blur;
  final Color? tint;

  /// Drawn under the image and used to choose the caption colour.
  final Color fallback;

  @override
  Brightness get brightness => _brightnessOf(fallback);
}

class _ScreenBackground extends FrameBackground {
  const _ScreenBackground({
    this.blur = 30,
    this.tint = const Color(0x66000000),
    this.fallback = const Color(0xFF1C1C1E),
    this.brightness = Brightness.dark,
  }) : assert(blur >= 0);
  final double blur;
  final Color tint;
  final Color fallback;

  @override
  final Brightness brightness;
}

class _CustomBackground extends FrameBackground {
  const _CustomBackground(this.paint, {this.brightness = Brightness.light});
  final void Function(Canvas canvas, Size size) paint;

  @override
  final Brightness brightness;
}

Brightness _brightnessOf(Color c) =>
    c.computeLuminance() > 0.45 ? Brightness.light : Brightness.dark;

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
    this.slideLayout,
    @Deprecated(
      'Use slideLayout: SlideLayout.captionTop / .captionBottom / .bleed(). '
      'Removed in 2.0.',
    )
    this.layout = FrameLayout.captionTop,
    @Deprecated('Use slideLayout: SlideLayout.bleed(...). Removed in 2.0.')
    this.bleed,
    this.device,
    this.canvasSize,
    this.referenceSize = const Size(440, 956),
    this.decorations = const [],
    @Deprecated('Use device: DeviceStyle(bezel: ...). Removed in 2.0.')
    this.bezel = const DeviceBezel(),
    @Deprecated('Use device: DeviceStyle(cornerRadius: ...). Removed in 2.0.')
    this.screenCornerRadius,
    @Deprecated(
      'Use slideLayout: SlideLayout.bleed(angle: ...). Removed in 2.0.',
    )
    this.tilt = -8,
    @Deprecated('Use device: DeviceStyle(shadow: ...). Removed in 2.0.')
    this.shadow = true,
  }) : assert(
         slideLayout == null || bleed == null,
         'Pass slideLayout or the deprecated bleed, not both.',
       ),
       assert(
         // `identical`, not `==`: this runs in const constructors, where only
         // primitive equality can be evaluated. The default is a canonical
         // constant, so it's identical exactly when the caller didn't set it.
         device == null ||
             (identical(bezel, const DeviceBezel()) &&
                 screenCornerRadius == null &&
                 shadow),
         'Set the bezel, corners and shadow on device: DeviceStyle(...), '
         'not on MarketingFrame.',
       );

  final FrameBackground background;
  final Caption? caption;

  /// Where the caption and device go. See [SlideLayout]. When null, the
  /// deprecated [bleed] or [layout] decide.
  final SlideLayout? slideLayout;

  /// Where the caption and device go: the 1.x enum. Ignored when
  /// [slideLayout] or [bleed] is set.
  @Deprecated(
    'Use slideLayout: SlideLayout.captionTop / .captionBottom / .bleed(). '
    'Removed in 2.0.',
  )
  final FrameLayout layout;

  /// A device running off the bottom edge, alongside the 1.x [layout].
  @Deprecated('Use slideLayout: SlideLayout.bleed(...). Removed in 2.0.')
  final FrameBleed? bleed;

  /// How the device is drawn. See [DeviceStyle]. Defaults to a rounded bezel
  /// with a shadow.
  final DeviceStyle? device;

  /// Output size in pixels. Defaults to the device's full-screen pixel size,
  /// so a store preset device produces an upload-ready image. Set this to
  /// show one device on a different store's canvas, e.g. a 20:9 phone on
  /// Google Play's 1080 × 1920.
  final Size? canvasSize;

  /// The canvas that caption sizes, margins and gaps are designed for, in
  /// points. The default is a 6.9" iPhone.
  ///
  /// On a canvas of a different size every one of them is scaled by
  /// `sqrt(canvas area / reference area)`, so text covers the same share of
  /// the image. Store listings show screenshots at similar sizes whatever the
  /// device, so a caption set in device points would shrink on tablets.
  final Size referenceSize;

  /// Logos, badges, stickers and other pieces placed on the canvas. See
  /// [FrameDecoration].
  final List<FrameDecoration> decorations;

  @Deprecated('Use device: DeviceStyle(bezel: ...). Removed in 2.0.')
  final DeviceBezel? bezel;

  @Deprecated('Use device: DeviceStyle(cornerRadius: ...). Removed in 2.0.')
  final double? screenCornerRadius;

  /// Rotation in degrees for [FrameLayout.tilted].
  @Deprecated('Use slideLayout: SlideLayout.bleed(angle: ...). Removed in 2.0.')
  final double tilt;

  @Deprecated('Use device: DeviceStyle(shadow: ...). Removed in 2.0.')
  final bool shadow;

  /// A copy with the given fields replaced, e.g. one slide's caption on a
  /// shared design: `brandFrame.copyWith(caption: Caption(headline: ...))`.
  /// A null argument keeps the current value, so `copyWith` can't remove a
  /// caption; build a new `MarketingFrame` for that. The caption is
  /// replaced whole; `Caption.styledLike` keeps the shared caption's look.
  MarketingFrame copyWith({
    FrameBackground? background,
    Caption? caption,
    SlideLayout? slideLayout,
    DeviceStyle? device,
    Size? canvasSize,
    Size? referenceSize,
    List<FrameDecoration>? decorations,
  }) => MarketingFrame(
    background: background ?? this.background,
    caption: caption ?? this.caption,
    slideLayout: slideLayout ?? this.slideLayout,
    layout: layout,
    bleed: slideLayout == null ? bleed : null,
    device: device ?? this.device,
    canvasSize: canvasSize ?? this.canvasSize,
    referenceSize: referenceSize ?? this.referenceSize,
    decorations: decorations ?? this.decorations,
    bezel: this.device == null && device == null ? bezel : const DeviceBezel(),
    screenCornerRadius: this.device == null && device == null
        ? screenCornerRadius
        : null,
    tilt: tilt,
    shadow: this.device == null && device == null ? shadow : true,
  );

  @override
  MarketingFrame resolve(ScreenshotContext context) => this;
}
