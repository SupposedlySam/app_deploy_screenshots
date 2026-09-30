import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'png_encoder.dart';
import 'variant.dart';

/// One written screenshot.
@immutable
class ScreenshotRecord {
  const ScreenshotRecord({
    required this.path,
    required this.context,
    required this.width,
    required this.height,
    required this.framed,
    this.captionCoverage,
  });

  final String path;
  final ScreenshotContext context;
  final int width;
  final int height;

  /// Whether a `MarketingFrame` was applied.
  final bool framed;

  /// Share of the image covered by caption text (0–1), or null without a
  /// frame. Google Play's guidance is to keep text overlays to 20% or less.
  final double? captionCoverage;

  Map<String, Object?> toJson(String root) {
    final device = context.device;
    return {
      'path': _relative(path, root),
      'name': context.name,
      'order': context.order,
      'device': device.name,
      'platform': device.platform.name,
      'width': width,
      'height': height,
      'logicalWidth': device.size.width,
      'logicalHeight': device.size.height,
      'devicePixelRatio': device.devicePixelRatio,
      'brightness': device.brightness.name,
      'locale': context.variant.locale?.toLanguageTag(),
      'variant': context.variant.suffix,
      'framed': framed,
      'captionCoverage': captionCoverage,
    };
  }
}

/// Screenshots written by this test isolate, in capture order.
///
/// Test files run in separate isolates, so this holds only the current
/// file's screenshots; [writeManifest] merges it with what is already on
/// disk.
final List<ScreenshotRecord> screenshotLog = [];

/// Directory under the output root that holds contact sheets, so upload
/// tools that take every PNG in a device folder never pick them up.
const String reviewDirectoryName = '_review';

/// Writes `<root>/manifest.json`: every screenshot this isolate recorded,
/// merged with entries already in the file whose images still exist, sorted
/// by path.
Future<File> writeManifest(String root) async {
  final file = File('$root/manifest.json');
  final entries = <String, Map<String, Object?>>{};
  if (file.existsSync()) {
    final existing = jsonDecode(file.readAsStringSync());
    if (existing is! Map || existing['screenshots'] is! List) {
      throw FormatException('Unrecognised manifest', file.path);
    }
    for (final e
        in (existing['screenshots'] as List).cast<Map<String, Object?>>()) {
      final path = e['path'] as String;
      if (File('$root/$path').existsSync()) entries[path] = e;
    }
  }
  for (final r in screenshotLog) {
    if (!_isUnder(r.path, root)) continue;
    entries[_relative(r.path, root)] = r.toJson(root);
  }
  final sorted = entries.keys.toList()..sort();
  final json = const JsonEncoder.withIndent('  ').convert({
    'screenshots': [for (final k in sorted) entries[k]],
  });
  await file.create(recursive: true);
  // Write then rename, so a reader never sees half a file.
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString('$json\n');
  return tmp.rename(file.path);
}

/// Screenshots in `<root>/manifest.json` for Google Play whose caption text
/// covers more than [limit] of the image, as `(path, coverage)` pairs.
List<(String, double)> captionCoverageOver(String root, double limit) {
  final file = File('$root/manifest.json');
  if (!file.existsSync()) return const [];
  final json = jsonDecode(file.readAsStringSync()) as Map;
  return [
    for (final e in (json['screenshots'] as List).cast<Map>())
      if (e['platform'] == 'android' &&
          e['captionCoverage'] is num &&
          (e['captionCoverage'] as num) > limit)
        (e['path'] as String, (e['captionCoverage'] as num).toDouble()),
  ];
}

/// Writes one contact sheet per directory of screenshots under [root], into
/// `<root>/_review/`. Each sheet is a grid of that directory's PNGs in file
/// name order, labelled with the file name.
///
/// With the default layouts a directory holds one device, so each sheet
/// shows one device's whole listing.
Future<List<File>> writeContactSheets(
  String root, {
  int columns = 5,
  double thumbnailHeight = 640,
  Color background = const Color(0xFFE5E5EA),
}) async {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final groups = <String, List<File>>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.png')) continue;
    final rel = _relative(entity.path, root);
    if (rel.split('/').first == reviewDirectoryName) continue;
    final parent = rel.contains('/')
        ? rel.substring(0, rel.lastIndexOf('/'))
        : '';
    groups.putIfAbsent(parent, () => []).add(entity);
  }

  final written = <File>[];
  for (final entry
      in (groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
    final files = entry.value..sort((a, b) => a.path.compareTo(b.path));
    final sheetName = entry.key.isEmpty
        ? 'all'
        : entry.key.replaceAll('/', '__');
    final out = File('$root/$reviewDirectoryName/$sheetName.png');
    await out.create(recursive: true);
    await out.writeAsBytes(
      await _contactSheet(files, columns, thumbnailHeight, background),
    );
    written.add(out);
  }
  return written;
}

Future<Uint8List> _contactSheet(
  List<File> files,
  int columns,
  double thumbHeight,
  Color background,
) async {
  final images = <ui.Image>[];
  for (final f in files) {
    final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
    images.add((await codec.getNextFrame()).image);
  }
  const pad = 32.0, labelHeight = 36.0;
  final widths = [for (final i in images) i.width * thumbHeight / i.height];
  final cellWidth = widths.reduce(math.max);
  final cols = math.min(columns, images.length);
  final rows = (images.length / cols).ceil();
  final size = Size(
    pad + cols * (cellWidth + pad),
    pad + rows * (thumbHeight + labelHeight + pad),
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size)
    ..drawRect(Offset.zero & size, Paint()..color = background);
  for (var i = 0; i < images.length; i++) {
    final x =
        pad + (i % cols) * (cellWidth + pad) + (cellWidth - widths[i]) / 2;
    final y = pad + (i ~/ cols) * (thumbHeight + labelHeight + pad);
    final dst = Rect.fromLTWH(x, y, widths[i], thumbHeight);
    canvas.drawRect(dst.inflate(1), Paint()..color = const Color(0x33000000));
    canvas.drawImageRect(
      images[i],
      Offset.zero &
          Size(images[i].width.toDouble(), images[i].height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final label = TextPainter(
      text: TextSpan(
        text: files[i].uri.pathSegments.last,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          color: Color(0xFF3A3A3C),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: cellWidth);
    label.paint(
      canvas,
      Offset(x + (widths[i] - label.width) / 2, y + thumbHeight + 8),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  picture.dispose();
  final bytes = await encodeOpaquePng(image, background: background);
  image.dispose();
  for (final i in images) {
    i.dispose();
  }
  return bytes;
}

String _normalise(String path) {
  var p = path.replaceAll('\\', '/');
  while (p.startsWith('./')) {
    p = p.substring(2);
  }
  return p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}

bool _isUnder(String path, String root) =>
    _normalise(path).startsWith('${_normalise(root)}/');

String _relative(String path, String root) {
  final p = _normalise(path), r = _normalise(root);
  return p.startsWith('$r/') ? p.substring(r.length + 1) : p;
}
