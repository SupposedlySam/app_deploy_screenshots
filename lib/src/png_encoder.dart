import 'dart:typed_data';
import 'dart:ui' as ui;

import 'output/png_encoder.dart';

/// Encodes [image] as a 24-bit RGB PNG with no alpha channel, compositing
/// translucent pixels over [background]. See [PngEncoder.encode].
@Deprecated('Every screenshot is already written this way. Removed in 2.0.')
Future<Uint8List> encodeOpaquePng(
  ui.Image image, {
  ui.Color background = const ui.Color(0xFFFFFFFF),
}) => PngEncoder.encode(image, background: background);
