import 'package:app_deploy_screenshots/golden_toolkit/golden_toolkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('First page screenshot', (tester) async {
    await tester.waitForAssets();

    await tester.pumpWidgetBuilder(const Scaffold(
      body: Center(child: Text('First page')),
    ));

    await tester.pumpAndSettle();

    await createAllByPlatformAndDevice(tester, 'first_page');

    expect(true, isTrue);
  });
}
