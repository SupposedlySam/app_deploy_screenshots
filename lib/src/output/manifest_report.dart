import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../capture/capture_session.dart';
import 'report.dart';

/// Writes the manifest and contact sheets, and checks Google Play's text
/// guidance. Shared by `AppDeployScreenshots.writeReport` and
/// `StoreListing.writeReport`.
abstract final class ManifestReport {
  static Future<List<(String path, double coverage)>> write({
    required String root,
    required CaptureSession session,
    WidgetTester? tester,
    bool manifest = true,
    bool contactSheets = true,
    int columns = 5,
    double? playCaptionCoverageLimit = 0.2,
  }) async {
    Future<void> write() async {
      if (manifest) await Manifest.write(root, session.records);
      if (contactSheets) await ContactSheets.write(root, columns: columns);
    }

    await (tester == null ? write() : tester.runAsync(write));

    final limit = playCaptionCoverageLimit;
    if (limit == null || !manifest) return const [];
    final over = Manifest.captionCoverageOver(root, limit);
    for (final (path, coverage) in over) {
      debugPrint(
        '⚠️ app_deploy_screenshots: $path caption covers '
        '${(coverage * 100).toStringAsFixed(1)}% of the image '
        '(Google Play guidance: ${(limit * 100).round()}% or less)',
      );
    }
    return over;
  }
}
