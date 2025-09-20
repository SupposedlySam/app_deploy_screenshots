import 'dart:async';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

// All tests in this folder and its subfolders will have the configuration defined here

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppDeployScreenshots.initialize();

  return testMain();
}
