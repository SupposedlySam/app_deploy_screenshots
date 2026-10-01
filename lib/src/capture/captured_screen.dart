import 'dart:ui' as ui;
import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

import '../../device.dart';
import '../annotations.dart';

/// One raw capture plus everything later stages need to place, annotate and
/// frame it, so no stage has to read the widget tree again.
class CapturedScreen {
  CapturedScreen({
    required this.image,
    required this.viewRect,
    required this.viewSize,
    required this.device,
    required this.annotations,
    required this.statusBarIcons,
  });

  /// The capture, in pixels.
  final ui.Image image;

  /// The part of the view the image covers, in logical points. The whole
  /// view for a full-screen capture; a widget's bounds for a `finder`.
  final Rect viewRect;

  /// The whole view, in logical points.
  final Size viewSize;

  final Device device;

  /// Annotation targets, found under this device's overrides.
  final List<ResolvedAnnotation> annotations;

  /// The icon brightness the status bar should use.
  final Brightness statusBarIcons;

  /// Image pixels per logical point.
  double get pixelsPerPoint => image.width / viewRect.width;

  /// Maps a point in view coordinates (logical) to image pixels.
  Offset viewToImage(Offset p) => (p - viewRect.topLeft) * pixelsPerPoint;

  /// Whether the capture includes the top of the screen, where the status bar
  /// sits.
  bool get coversTopOfScreen =>
      viewRect.top <= 0 && viewRect.width >= viewSize.width;
}
