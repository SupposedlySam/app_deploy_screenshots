import 'dart:async';
import 'dart:io';

import 'package:app_deploy_screenshots/golden_toolkit/golden_toolkit.dart';

// All tests in this folder and its subfolders will have the configuration defined here

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AppDeployToolkit.runWithConfiguration(
    () async {
      await loadAppFonts();
      await testMain();
    },
    config: AppDeployToolkitConfiguration(
      // Currently, goldens are not generated/validated in CI for this repo. We have settled on the goldens for this package
      // being captured/validated by developers running on MacOSX. We may revisit this in the future if there is a reason to invest
      // in more sophistication
      skipGoldenAssertion: () => !Platform.isMacOS,
      enableRealShadows: true,
    ),
  );
}
