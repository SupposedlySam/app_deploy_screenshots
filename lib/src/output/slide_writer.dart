import 'dart:io';
import 'dart:ui' as ui;

import '../capture/capture_session.dart';
import '../variant.dart';
import 'png_encoder.dart';
import 'report.dart';

/// Writes a finished image: encoding, the file, the record and the session
/// log. Every screenshot ends here, whatever made its image, so naming, the
/// manifest and contact sheets treat them all the same.
class SlideWriter {
  const SlideWriter(this.session);

  final CaptureSession session;

  /// Encodes [image] as a store-safe PNG at [path], records it, and disposes
  /// the image. Run outside the fake-async zone.
  Future<ScreenshotRecord> write(
    ScreenshotContext context,
    ui.Image image, {
    required String path,
    bool framed = false,
    double? captionCoverage,
    ScreenshotSource source = ScreenshotSource.app,
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
      source: source,
    );
    image.dispose();
    session.records.add(record);
    return record;
  }
}
