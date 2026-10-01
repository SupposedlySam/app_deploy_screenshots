import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../capture/captured_screen.dart';
import '../status_bar.dart';
import 'annotation_painter.dart';
import 'frame_geometry.dart';

/// Draws onto the screenshot itself: the status bar and the annotations that
/// belong to the screen, so they scale and rotate with it in a frame.
abstract final class ScreenOverlays {
  /// Returns a new image of [captured] with [statusBar] and the screen-level
  /// annotations drawn. With [includeCanvasAnnotations], canvas-level
  /// annotations (magnifiers) are drawn too, for a screenshot that will not
  /// be framed. Run outside the fake-async zone.
  static Future<ui.Image> apply(
    CapturedScreen captured, {
    StatusBarOverlay? statusBar,
    bool includeCanvasAnnotations = false,
  }) async {
    final raw = captured.image;
    final imageSize = Size(raw.width.toDouble(), raw.height.toDouble());
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
    if (includeCanvasAnnotations) {
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
    final image = await picture.toImage(raw.width, raw.height);
    picture.dispose();
    return image;
  }
}
