import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'variant.dart';

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

/// Maps a point in the screenshot image to the output canvas.
typedef ImageToCanvas = Offset Function(Offset imagePoint);

/// The result of compositing: the canvas and how the screenshot was placed.
class FramedScreenshot {
  FramedScreenshot(
    this.image,
    this.imageToCanvas,
    this.canvasPerImagePixel,
    this.captionCoverage,
  );

  final ui.Image image;
  final ImageToCanvas imageToCanvas;
  final double canvasPerImagePixel;

  /// Share of the canvas covered by caption text: the area of the text's
  /// line boxes over the canvas area, 0–1.
  final double captionCoverage;
}

/// Composites [screen] onto [frame]'s canvas.
///
/// [pointWidth] is the device's width in logical points; it sets the bezel
/// thickness, which belongs to the device. [screenLogicalWidth] is the width of the
/// captured area in logical points. [afterScreen] paints over the finished
/// canvas, given the screen placement (used for magnifiers).
Future<FramedScreenshot> composeFrame({
  required MarketingFrame frame,
  required ui.Image screen,
  required double pointWidth,
  required double screenLogicalWidth,
  required double defaultCornerRadius,
  void Function(
    Canvas canvas,
    Size canvasSize,
    ImageToCanvas map,
    double scale,
  )?
  afterScreen,
}) async {
  final canvasSize =
      frame.canvasSize ??
      Size(screen.width.toDouble(), screen.height.toDouble());
  // Canvas px per layout point: captions, margins and gaps.
  final pt = math.sqrt(
    canvasSize.width *
        canvasSize.height /
        (frame.referenceSize.width * frame.referenceSize.height),
  );
  // Canvas px per device point: the bezel, which belongs to the device.
  final devicePt = canvasSize.width / pointWidth;
  final screenPerPt = screen.width / screenLogicalWidth; // image px per point

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & canvasSize);
  await _paintBackground(canvas, canvasSize, frame.background);

  final margin = 24 * pt;
  final captionPainters = _captionPainters(
    frame,
    canvasSize.width - 2 * margin,
    pt,
  );
  final captionHeight = captionPainters.isEmpty
      ? 0.0
      : captionPainters.fold<double>(0, (h, p) => h + p.height) +
            8 * pt * (captionPainters.length - 1);
  final captionGap = captionPainters.isEmpty ? 0.0 : 28 * pt;

  final bezel = (frame.bezel?.width ?? 0) * devicePt;
  final screenAspect = screen.height / screen.width;

  // Where the screen (inside the bezel) goes, before any rotation.
  late Rect screenRect;
  late double captionTop;
  final topPad = 48 * pt;
  switch (frame.layout) {
    case FrameLayout.captionTop:
    case FrameLayout.captionBottom:
      final availW = canvasSize.width - 2 * margin - 2 * bezel;
      final availH =
          canvasSize.height -
          topPad -
          margin -
          captionHeight -
          captionGap -
          2 * bezel;
      final w = math.min(availW * 0.86, availH / screenAspect);
      final h = w * screenAspect;
      final left = (canvasSize.width - w) / 2;
      if (frame.layout == FrameLayout.captionTop) {
        captionTop = topPad;
        final top = topPad + captionHeight + captionGap + bezel;
        screenRect = Rect.fromLTWH(left, top, w, h);
      } else {
        final top = topPad * 0.6 + bezel;
        screenRect = Rect.fromLTWH(left, top, w, h);
        captionTop = screenRect.bottom + bezel + captionGap;
      }
    case FrameLayout.tilted:
      captionTop = topPad;
      final w = (canvasSize.width - 2 * margin) * 0.8;
      final top = topPad + captionHeight + captionGap + bezel + 16 * pt;
      screenRect = Rect.fromLTWH(
        (canvasSize.width - w) / 2,
        top,
        w,
        w * screenAspect,
      );
  }

  var y = captionTop;
  for (final p in captionPainters) {
    p.paint(canvas, Offset(margin, y));
    y += p.height + 8 * pt;
  }

  final scale = screenRect.width / screen.width; // canvas px per image px
  final angle = frame.layout == FrameLayout.tilted
      ? frame.tilt * math.pi / 180
      : 0.0;
  final centre = screenRect.center;

  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.rotate(angle);
  final local = Rect.fromCenter(
    center: Offset.zero,
    width: screenRect.width,
    height: screenRect.height,
  );
  final radius =
      (frame.screenCornerRadius ?? defaultCornerRadius) * screenPerPt * scale;
  final screenShape = RRect.fromRectAndRadius(local, Radius.circular(radius));
  final outer = screenShape.inflate(bezel);

  if (frame.shadow) {
    canvas.drawRRect(
      outer.shift(Offset(0, 12 * pt)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * pt),
    );
  }
  if (frame.bezel != null) {
    canvas.drawRRect(outer, Paint()..color = frame.bezel!.color);
  }
  canvas.clipRRect(screenShape);
  canvas.drawImageRect(
    screen,
    Offset.zero & Size(screen.width.toDouble(), screen.height.toDouble()),
    local,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();

  Offset map(Offset p) {
    final dx = (p.dx - screen.width / 2) * scale;
    final dy = (p.dy - screen.height / 2) * scale;
    final c = math.cos(angle), s = math.sin(angle);
    return Offset(centre.dx + dx * c - dy * s, centre.dy + dx * s + dy * c);
  }

  afterScreen?.call(canvas, canvasSize, map, scale);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    canvasSize.width.round(),
    canvasSize.height.round(),
  );
  picture.dispose();
  // Line boxes, not the caption's layout box: a short headline centred in a
  // wide box covers only what it inks.
  final textArea = captionPainters.fold<double>(
    0,
    (sum, p) =>
        sum +
        p.computeLineMetrics().fold<double>(
          0,
          (a, l) => a + l.width * l.height,
        ),
  );
  return FramedScreenshot(
    image,
    map,
    scale,
    textArea / (canvasSize.width * canvasSize.height),
  );
}

List<TextPainter> _captionPainters(
  MarketingFrame frame,
  double width,
  double pt,
) {
  final caption = frame.caption;
  if (caption == null) return const [];
  final ink = frame.background.brightness == Brightness.light
      ? const Color(0xFF111111)
      : const Color(0xFFFFFFFF);

  TextPainter make(String text, TextStyle base, TextStyle? custom) {
    final style = base.merge(custom);
    // Caption sizes are points; scale every metric to canvas pixels.
    final scaled = style.copyWith(
      fontSize: (style.fontSize ?? 14) * pt,
      letterSpacing: style.letterSpacing == null
          ? null
          : style.letterSpacing! * pt,
    );
    return TextPainter(
      text: TextSpan(text: text, style: scaled),
      textAlign: caption.textAlign,
      textDirection: caption.textDirection,
    )..layout(minWidth: width, maxWidth: width);
  }

  return [
    make(
      caption.headline,
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: ink,
      ),
      caption.headlineStyle,
    ),
    if (caption.subheadline != null)
      make(
        caption.subheadline!,
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 17,
          height: 1.3,
          color: ink.withValues(alpha: 0.72),
        ),
        caption.subheadlineStyle,
      ),
  ];
}

Future<void> _paintBackground(
  Canvas canvas,
  Size size,
  FrameBackground bg,
) async {
  final rect = Offset.zero & size;
  switch (bg) {
    case _SolidBackground(:final color):
      canvas.drawRect(rect, Paint()..color = color);
    case _GradientBackground(:final gradient):
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    case _ImageBackground(:final bytes, :final fallback):
      canvas.drawRect(rect, Paint()..color = fallback);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final fitted = applyBoxFit(
        BoxFit.cover,
        Size(image.width.toDouble(), image.height.toDouble()),
        size,
      );
      final src = Alignment.center.inscribe(
        fitted.source,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      );
      canvas.drawImageRect(
        image,
        src,
        rect,
        Paint()..filterQuality = FilterQuality.high,
      );
    case _CustomBackground(:final paint):
      paint(canvas, size);
  }
}
