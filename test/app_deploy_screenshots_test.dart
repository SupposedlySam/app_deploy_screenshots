import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_deploy_screenshots/app_deploy_screenshots.dart';

void main() {
  // Cleanup files after tests
  tearDownAll(() {
    try {
      final screenshotDir = Directory('app_deploy_screenshots');
      if (screenshotDir.existsSync()) {
        screenshotDir.deleteSync(recursive: true);
      }

      // Clean up individual test files
      final testFiles = [
        'test_screenshot.png',
        'test_finder_screenshot.png',
        'test_pump_screenshot.png',
        'test_no_wait_screenshot.png',
      ];

      for (final fileName in testFiles) {
        final file = File(fileName);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('AppDeployScreenshots', () {
    group('byDevices', () {
      testWidgets('should capture screenshots for default devices', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevices(tester, 'test_default_devices');

        // Verify files were created
        expect(
          File(
            'app_deploy_screenshots/iphone16_pro.test_default_devices.png',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            'app_deploy_screenshots/ipad_pro_m4.test_default_devices.png',
          ).existsSync(),
          isTrue,
        );
      });

      testWidgets('should capture screenshots for custom devices', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevices(
          tester,
          'test_custom_devices',
          devices: [Device.iphone11, Device.tabletPortrait],
        );

        // Verify files were created
        expect(
          File(
            'app_deploy_screenshots/iphone11.test_custom_devices.png',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            'app_deploy_screenshots/tablet_portrait.test_custom_devices.png',
          ).existsSync(),
          isTrue,
        );
      });

      testWidgets('should use custom finder', (tester) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevices(
          tester,
          'test_custom_finder',
          finder: find.byType(Scaffold),
          devices: [Device.phone],
        );

        expect(
          File(
            'app_deploy_screenshots/phone.test_custom_finder.png',
          ).existsSync(),
          isTrue,
        );
      });

      testWidgets('should use custom pump function', (tester) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevices(
          tester,
          'test_custom_pump',
          customPump: (tester) async {
            await tester.pump(const Duration(milliseconds: 100));
          },
          devices: [Device.phone],
        );

        expect(
          File(
            'app_deploy_screenshots/phone.test_custom_pump.png',
          ).existsSync(),
          isTrue,
        );
      });

      testWidgets('should use device setup function', (tester) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevices(
          tester,
          'test_device_setup',
          deviceSetup: (device, tester) async {
            await tester.pump();
            await tester.pump();
            // Custom device setup logic
          },
          devices: [Device.phone],
        );

        expect(
          File(
            'app_deploy_screenshots/phone.test_device_setup.png',
          ).existsSync(),
          isTrue,
        );
      });

      testWidgets('should fail with assertion when devices list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        expect(
          () => AppDeployScreenshots.byDevices(
            tester,
            'test_empty_devices',
            devices: [],
          ),
          throwsAssertionError,
        );
      });
    });

    group('byPlatform', () {
      testWidgets('should capture screenshots for all platform devices', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byPlatform(tester, 'test_all_platforms');

        // Verify that some iOS and Android device screenshots were created
        final iosDir = Directory('app_deploy_screenshots/ios');
        final androidDir = Directory('app_deploy_screenshots/android');

        expect(iosDir.existsSync(), isTrue);
        expect(androidDir.existsSync(), isTrue);

        // Check that files exist in subdirectories
        final iosFiles = iosDir.listSync(recursive: true).whereType<File>();
        final androidFiles = androidDir
            .listSync(recursive: true)
            .whereType<File>();

        expect(iosFiles.isNotEmpty, isTrue);
        expect(androidFiles.isNotEmpty, isTrue);
      });

      testWidgets('should use custom finder for platform screenshots', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byPlatform(
          tester,
          'test_platform_finder',
          finder: find.byType(Scaffold),
        );

        final iosDir = Directory('app_deploy_screenshots/ios');
        expect(iosDir.existsSync(), isTrue);
      });

      testWidgets('should use custom pump for platform screenshots', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byPlatform(
          tester,
          'test_platform_pump',
          customPump: (tester) async {
            await tester.pump(const Duration(milliseconds: 50));
          },
        );

        final iosDir = Directory('app_deploy_screenshots/ios');
        expect(iosDir.existsSync(), isTrue);
      });
    });

    group('byDevice', () {
      testWidgets('should capture screenshot with required parameters', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevice(
          tester,
          'test_required_params',
          fileName: 'test_screenshot.png',
          device: Device.phone,
        );

        expect(File('test_screenshot.png').existsSync(), isTrue);
      });

      testWidgets('should capture screenshot with custom finder', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevice(
          tester,
          'test_custom_finder_capture',
          fileName: 'test_finder_screenshot.png',
          device: Device.phone,
          finder: find.byType(Scaffold),
        );

        expect(File('test_finder_screenshot.png').existsSync(), isTrue);
      });

      testWidgets('should capture screenshot with custom pump', (tester) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevice(
          tester,
          'test_custom_pump_capture',
          fileName: 'test_pump_screenshot.png',
          device: Device.phone,
          customPump: (tester) async {
            await tester.pump(const Duration(milliseconds: 100));
          },
        );

        expect(File('test_pump_screenshot.png').existsSync(), isTrue);
      });

      testWidgets('should capture screenshot without waiting for images', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        await AppDeployScreenshots.byDevice(
          tester,
          'test_no_wait_images',
          fileName: 'test_no_wait_screenshot.png',
          device: Device.phone,
          waitForImages: false,
        );

        expect(File('test_no_wait_screenshot.png').existsSync(), isTrue);
      });

      testWidgets('should fail assertion when name ends with .png', (
        tester,
      ) async {
        await tester.pumpWidget(const TestApp());

        expect(
          () => AppDeployScreenshots.byDevice(
            tester,
            'test.png',
            fileName: 'test_assertion.png',
            device: Device.phone,
          ),
          throwsAssertionError,
        );
      });
    });

    group('captureImage', () {
      testWidgets(
        'should handle elements with valid RepaintBoundary in minimal tree',
        (tester) async {
          // Even minimal widget trees have RepaintBoundaries from Flutter framework
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              // ignore: avoid_unnecessary_containers
              child: Container(child: const Text('Minimal Tree')),
            ),
          );

          final finder = find.text('Minimal Tree');
          final element = finder.evaluate().first;

          // Should successfully find a RepaintBoundary (Flutter creates them automatically)
          expect(
            () => AppDeployScreenshots.captureImage(element),
            returnsNormally,
          );

          final image = await AppDeployScreenshots.captureImage(element);
          expect(image.width, greaterThan(0));
          expect(image.height, greaterThan(0));
        },
      );

      testWidgets(
        'should successfully capture image when RepaintBoundary exists',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: RepaintBoundary(
                child: Scaffold(
                  body: const Center(child: Text('With RepaintBoundary')),
                ),
              ),
            ),
          );

          final finder = find.text('With RepaintBoundary');
          final element = finder.evaluate().first;

          // Should not throw and should return a Future<ui.Image>
          expect(
            () => AppDeployScreenshots.captureImage(element),
            returnsNormally,
          );

          final imageFuture = AppDeployScreenshots.captureImage(element);
          expect(imageFuture, isA<Future<ui.Image>>());

          // Verify the image can be awaited without errors
          final image = await imageFuture;
          expect(image.width, greaterThan(0));
          expect(image.height, greaterThan(0));
        },
      );

      testWidgets('should find RepaintBoundary in ancestor chain', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              child: Scaffold(
                // ignore: avoid_unnecessary_containers
                body: Container(
                  child: Column(children: [const Text('Nested Widget')]),
                ),
              ),
            ),
          ),
        );

        final finder = find.text('Nested Widget');
        final element = finder.evaluate().first;

        // Should successfully find the RepaintBoundary ancestor
        expect(
          () => AppDeployScreenshots.captureImage(element),
          returnsNormally,
        );

        final image = await AppDeployScreenshots.captureImage(element);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));
      });

      testWidgets(
        'should validate that captureImage method is accessible and functional',
        (tester) async {
          // Test that the method exists and can be called without runtime errors
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: const Center(child: Text('Test Method Access')),
              ),
            ),
          );

          final finder = find.text('Test Method Access');
          final element = finder.evaluate().first;

          // Verify method signature and basic functionality
          final imageFuture = AppDeployScreenshots.captureImage(element);
          expect(imageFuture, isA<Future<ui.Image>>());

          final image = await imageFuture;
          expect(image, isA<ui.Image>());
          expect(image.width, isA<int>());
          expect(image.height, isA<int>());
          expect(image.width, greaterThan(0));
          expect(image.height, greaterThan(0));
        },
      );
    });
  });

  // Original screenshot test
  testWidgets('First page screenshot', (tester) async {
    await tester.pumpWidget(const CounterApp());

    await tester.pumpAndSettle();

    await AppDeployScreenshots.byPlatform(tester, 'initial_state');

    await tester.tap(find.byType(ElevatedButton));

    await tester.pumpAndSettle();

    await AppDeployScreenshots.byPlatform(tester, 'incremented_state');

    expect(true, isTrue);
  }, tags: ['app_deploy_screenshots']);
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Test App'))),
    );
  }
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
