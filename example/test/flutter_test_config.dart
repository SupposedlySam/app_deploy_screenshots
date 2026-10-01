import 'dart:async';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

// Runs before every test in this folder: loads the app's fonts (including
// Material icons) and the package's emoji font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppDeployScreenshots.initialize();
  return testMain();
}
