import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

void main() {
  testWidgets('First page screenshot', (tester) async {
    await tester.waitForAssets();

    await tester.pumpWidgetBuilder(const CounterApp());

    await tester.pumpAndSettle();

    await captureByPlatformAndDevice(tester, 'initial_state');

    await tester.tap(find.byType(ElevatedButton));

    await tester.pumpAndSettle();

    await captureByPlatformAndDevice(tester, 'incremented_state');

    expect(true, isTrue);
  }, tags: ['app_deploy_screenshots']);
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterPage());
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _counter = 0;

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$_counter'),
            ElevatedButton(
              onPressed: _increment,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
