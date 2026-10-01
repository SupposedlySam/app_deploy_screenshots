import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../annotations.dart';
import '../capture/capture_session.dart';
import '../capture/captured_screen.dart';
import '../frame/frame_compositor.dart';
import '../frame/frame_geometry.dart';
import '../frame/marketing_frame.dart';
import '../status_bar.dart';
import '../variant.dart';
import 'png_encoder.dart';
import 'report.dart';

/// Turns a capture into a finished file: overlays, frame, encoding, writing
/// and the record. Every slide, whatever made its image, ends here, so file
/// naming, the manifest and the log treat all slides the same.
///
/// Call it outside the fake-async zone (inside `tester.runAsync`); it does
/// real image work.
class SlideWriter {
  const SlideWriter(this.session, [this.compositor = const FrameCompositor()]);

  final CaptureSession session;
  final FrameCompositor compositor;

  /// Draws [statusBar] and the annotations onto [captured], frames it with
  /// [frame] if given, and writes it to [path].
  Future<ScreenshotRecord> writeScreen(
    ScreenshotContext context,
    CapturedScreen captured, {
    required String path,
    StatusBarOverlay? statusBar,
    MarketingFrame? frame,
  }) async {
    final raw = captured.image;
    final imageSize = Size(raw.width.toDouble(), raw.height.toDouble());

    // Status bar and screen-level annotations, in view coordinates.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawImage(raw, Offset.zero, Paint());
    canvas
      ..save()
      ..scale(captured.pixelsPerPoint)
      ..translate(-captured.viewRect.left, -captured.viewRect.top);
    statusBar?.paint(canvas, captured.device, icons: captured.statusBarIcons);
    AnnotationPainter.paintOnScreen(
      canvas,
      captured.viewSize,
      captured.annotations,
    );
    canvas.restore();
    if (frame == null) {
      // No canvas: canvas-level annotations go on the screenshot itself.
      AnnotationPainter.paintOnCanvas(
        canvas,
        captured: captured,
        placement: ScreenPlacement(
          rect: Offset.zero & imageSize,
          angle: 0,
          imageSize: imageSize,
          viewRect: captured.viewRect,
        ),
        canvasSize: imageSize,
      );
    }
    final picture = recorder.endRecording();
    final screen = await picture.toImage(raw.width, raw.height);
    picture.dispose();

    if (frame == null) {
      return writeImage(context, screen, path: path);
    }
    final composed = await compositor.compose(
      frame: frame,
      screenImage: screen,
      captured: captured,
    );
    screen.dispose();
    return writeImage(
      context,
      composed.image,
      path: path,
      framed: true,
      captionCoverage: composed.captionCoverage,
    );
  }

  /// Encodes [image] as a store-safe PNG, writes it to [path], records it in
  /// the session and disposes the image.
  Future<ScreenshotRecord> writeImage(
    ScreenshotContext context,
    ui.Image image, {
    required String path,
    bool framed = false,
    double? captionCoverage,
    SlideKind kind = SlideKind.screenshot,
  }) async {
    final bytes = await PngEncoder.encode(image);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    final record = ScreenshotRecord(
      path: path,
      context: context,
      width: image.width,
      height: image.height,
      framed: framed,
      captionCoverage: captionCoverage,
      kind: kind,
    );
    image.dispose();
    session.records.add(record);
    return record;
  }
}
