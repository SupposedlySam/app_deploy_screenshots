import 'dart:ui' show Brightness;

import '../output/report.dart';

/// State shared by every capture in one test isolate.
///
/// Kept in one object rather than in statics scattered across the pipeline,
/// so its lifetime is explicit and a listing can own one.
class CaptureSession {
  /// The session used by the static `AppDeployScreenshots` methods.
  static final CaptureSession shared = CaptureSession();

  /// Brightness of the app at the last capture, to know when a theme
  /// transition has to be stepped through. Null when unknown, which counts
  /// as a change.
  Brightness? lastBrightness;

  /// Every image written in this isolate, in capture order. Feeds the
  /// manifest.
  final List<ScreenshotRecord> records = [];
}
