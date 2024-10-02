/// ***************************************************
/// Copyright 2019-2020 eBay Inc.
///
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file or at
/// https://opensource.org/licenses/BSD-3-Clause
/// ***************************************************
library;

//ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'configuration.dart';
import 'device.dart';
import 'device_builder.dart';
import 'test_asset_bundle.dart';
import 'widget_tester_extensions.dart';

const Size _defaultSize = Size(800, 600);

///CustomPump is a function that lets you do custom pumping before golden evaluation.
///Sometimes, you want to do a golden test for different stages of animations, so its crucial to have a precise control over pumps and durations
typedef CustomPump = Future<void> Function(WidgetTester);

/// Typedef for wrapping a widget with one or more other widgets
typedef WidgetWrapper = Widget Function(Widget);

/// Hook for running arbitrary behavior for a particular scenario
typedef OnScenarioCreate = Future<void> Function(Key scenarioWidgetKey);

/// Extensions for a [WidgetTester]
extension TestingToolsExtension on WidgetTester {
  /// Extension for a [WidgetTester] that pumps the widget and provides an optional [WidgetWrapper]
  ///
  /// [WidgetWrapper] defaults to [materialAppWrapper]
  ///
  /// [surfaceSize] set's the surface size, defaults to [_defaultSize]
  ///
  /// [textScaleSize] set's the text scale size (usually in a range from 1 to 3)
  Future<void> pumpWidgetBuilder(
    Widget widget, {
    WidgetWrapper? wrapper,
    Size surfaceSize = _defaultSize,
    double textScaleSize = 1.0,
  }) async {
    final wrap = wrapper ?? materialAppWrapper();

    await _pumpAppWidget(
      this,
      wrap(widget),
      surfaceSize: surfaceSize,
      textScaleSize: textScaleSize,
    );
  }

  /// Extension for a [WidgetTester] that pumps a [DeviceBuilder] class
  ///
  /// [WidgetWrapper] defaults to [materialAppWrapper]
  ///
  /// [textScaleSize] set's the text scale size (usually in a range from 1 to 3)
  Future<void> pumpDeviceBuilder(
    DeviceBuilder deviceBuilder, {
    WidgetWrapper? wrapper,
  }) async {
    await pumpWidgetBuilder(
      deviceBuilder.build(),
      wrapper: wrapper,
      surfaceSize: deviceBuilder.requiredWidgetSize,
    );

    for (final scenario in deviceBuilder.scenarios) {
      await scenario.onCreate?.call(scenario.key);
    }
  }
}

/// This [materialAppWrapper] is a convenience function to wrap your widget in [MaterialApp]
/// Wraps your widget in MaterialApp, inject  custom theme, localizations, override  surfaceSize and platform
///
/// [platform] will override Theme's platform. [theme] is required
///
/// [localizations] is list of [LocalizationsDelegate] that is required for this test
///
/// [navigatorObserver] is an interface for observing the behavior of a [Navigator].
///
/// [localeOverrides] will set supported supportedLocales, defaults to [Locale('en')]
///
/// [theme] Your app theme
WidgetWrapper materialAppWrapper({
  TargetPlatform platform = TargetPlatform.android,
  Iterable<LocalizationsDelegate<dynamic>>? localizations,
  NavigatorObserver? navigatorObserver,
  Iterable<Locale>? localeOverrides,
  ThemeData? theme,
}) {
  return (child) => MaterialApp(
        localizationsDelegates: localizations,
        supportedLocales: localeOverrides ?? const [Locale('en')],
        theme: theme?.copyWith(platform: platform),
        debugShowCheckedModeBanner: false,
        home: Material(child: child),
        navigatorObservers: [
          if (navigatorObserver != null) navigatorObserver,
        ],
      );
}

/// This [noWrap] is a convenience function if you don't want to wrap widgets in default [materialAppWrapper]
WidgetWrapper noWrap() => (child) => child;

Future<void> _pumpAppWidget(
  WidgetTester tester,
  Widget app, {
  required Size surfaceSize,
  required double textScaleSize,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleSize;

  await tester.pumpWidget(
    DefaultAssetBundle(bundle: TestAssetBundle(), child: app),
  );
  await tester.pump();
}

bool _inGoldenTest = false;

/// The default tag parameter. The parameter
/// is allowed to be null so we need something to compare against.
const Object _defaultTagObject = Object();

/// This [testGoldens] method exists as a way to enforce the proper naming of tests that contain golden diffs so that we can reliably run all goldens
///
/// [description] is a test description
///
/// [skip] to skip the test
///
/// [test] test body
///
@isTest
void testGoldens(
  String description,
  Future<void> Function(WidgetTester) test, {
  bool? skip,
  Object? tags = _defaultTagObject,
}) {
  final dynamic config = Zone.current[#goldentoolkit.config];
  testWidgets(
    description,
    (tester) async {
      Future<void> body() async {
        _inGoldenTest = true;
        final initialDebugDisableShadowsValue = debugDisableShadows;
        final shouldUseRealShadows =
            AppDeployToolkit.configuration.enableRealShadows;
        debugDisableShadows = !shouldUseRealShadows;
        try {
          await test(tester);
        } finally {
          debugDisableShadows = initialDebugDisableShadowsValue;
          _inGoldenTest = false;
        }
      }

      if (config is AppDeployToolkitConfiguration) {
        await AppDeployToolkit.runWithConfiguration(body, config: config);
      } else {
        await body();
      }
    },
    skip: skip,
    tags:
        tags != _defaultTagObject ? tags : AppDeployToolkit.configuration.tags,
  );
}

/// A function that wraps [matchesGoldenFile] with some extra functionality. The function finds the first widget
/// in the tree if [finder] is not specified. Furthermore a [fileNameFactory] can be used in combination with a [name]
/// to specify a custom path and name for the golden file. In addition to that the function makes sure all images are
/// available before
///
/// [name] is the name of the golden test and must NOT include extension like .png.
///
/// [finder] is an optional finder, which can be used to target a specific widget to use for the test. If not specified
/// the first widget in the tree is used
///
/// [autoHeight] tries to find the optimal height for the output surface. If there is a vertical scrollable this
/// ensures the whole scrollable is shown. If the targeted render box is smaller then the current height, this will
/// shrink down the output height to match the render boxes height.
///
/// [customPump] optional pump function, see [CustomPump] documentation
///
/// [skip] by setting to true will skip the golden file assertion. This may be necessary if your development platform is not the same as your CI platform
Future<void> screenMatchesGolden(
  WidgetTester tester,
  String name, {
  bool? autoHeight,
  Finder? finder,
  CustomPump? customPump,
  @Deprecated(
      'This method level parameter will be removed in an upcoming release. This can be configured globally. If you have concerns, please file an issue with your use case.')
  bool? skip,
}) {
  return compareWithGolden(
    tester,
    name,
    autoHeight: autoHeight,
    finder: finder,
    customPump: customPump,
    skip: skip,
    // This value is actually ignored. We are forced to pass it because the
    // downstream API is structured poorly. This should be refactored.
    device: Device.phone,
    fileNameFactory: (String name, Device device) =>
        AppDeployToolkit.configuration.fileNameFactory(name),
  );
}

// ignore: public_member_api_docs
Future<void> compareWithGolden(
  WidgetTester tester,
  String name, {
  required DeviceFileNameFactory fileNameFactory,
  required Device device,
  bool? autoHeight,
  Finder? finder,
  CustomPump? customPump,
  bool? skip,
}) async {
  assert(
    !name.endsWith('.png'),
    'Golden tests should not include file type',
  );
  if (!_inGoldenTest) {
    fail(
        'Golden tests MUST be run within a testGoldens method, not just a testWidgets method. This is so we can be confident that running "flutter test --name=GOLDEN" will run all golden tests.');
  }
  final shouldSkipGoldenGeneration =
      skip ?? AppDeployToolkit.configuration.skipGoldenAssertion();

  final pumpAfterPrime = customPump ?? _onlyPumpAndSettle;
  /* if no finder is specified, use the first widget. Note, there is no guarantee this evaluates top-down, but in theory if all widgets are in the same
  RepaintBoundary, it should not matter */
  final actualFinder = finder ?? find.byWidgetPredicate((w) => true).first;
  final fileName = fileNameFactory(name, device);
  final originalWindowSize = tester.view.physicalSize;

  if (!shouldSkipGoldenGeneration) {
    await tester.waitForAssets();
  }

  await pumpAfterPrime(tester);

  if (autoHeight == true) {
    // Find the first scrollable element which can be scrolled vertical.
    // ListView, SingleChildScrollView, CustomScrollView? are implemented using a Scrollable widget.
    final scrollable = find
        .byType(Scrollable)
        .evaluate()
        .map<ScrollableState?>((Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState) {
          return state;
        }
      }
      return null;
    }).firstWhere((state) {
      final position = state?.position;
      return position?.axisDirection == AxisDirection.down;
    }, orElse: () => null);

    final renderObject = tester.renderObject(actualFinder);

    var finalHeight = originalWindowSize.height;
    if (scrollable != null && scrollable.position.extentAfter.isFinite) {
      finalHeight = originalWindowSize.height + scrollable.position.extentAfter;
    } else if (renderObject is RenderBox) {
      finalHeight = renderObject.size.height;
    }

    final adjustedSize = Size(originalWindowSize.width, finalHeight);
    await tester.binding.setSurfaceSize(adjustedSize);
    tester.view.physicalSize = adjustedSize;

    await tester.pump();
  }

  await expectLater(
    actualFinder,
    matchesGoldenFile(fileName),
    skip: shouldSkipGoldenGeneration,
  );

  if (autoHeight == true) {
    // Here we reset the window size to its original value to be clean
    await tester.binding.setSurfaceSize(originalWindowSize);
    tester.view.physicalSize = originalWindowSize;
  }
}

/// A function that primes all assets by just wasting time and hoping that it is enough for all assets to
/// finish loading. Doing so is not recommended and very flaky. Consider switching to [defaultPrimeAssets] or
/// a custom implementation.
///
/// See also:
/// * [AppDeployToolkitConfiguration.primeAssets] to configure a global asset prime function.
Future<void> legacyPrimeAssets(WidgetTester tester) async {
  final renderObject = tester.binding.renderViews.first;
  assert(!renderObject.debugNeedsPaint);

  /* this should work but doesn't:
  final OffsetLayer layer = renderObject.debugLayer!;
  */
  final layer = renderObject.debugLayer as OffsetLayer;

  // This is a very flaky hack which should be avoided if possible.
  // We are just trying to waste some time that matches the time needed to call matchesGoldenFile.
  // This should be enough time for most images/assets to be ready.
  await tester.runAsync<void>(() async {
    final image = await layer.toImage(renderObject.paintBounds);
    await image.toByteData(format: ui.ImageByteFormat.png);
    await image.toByteData(format: ui.ImageByteFormat.png);
  });
}

/// A function that waits for all [Image] widgets found in the widget tree to finish decoding.
///
/// Currently this supports images included via Image widgets, or as part of BoxDecorations.
///
/// See also:
/// * [AppDeployToolkitConfiguration.primeAssets] to configure a global asset prime function.
Future<void> defaultPrimeAssets(WidgetTester tester) async {
  final imageElements = find.byType(Image, skipOffstage: false).evaluate();
  final containerElements =
      find.byType(DecoratedBox, skipOffstage: false).evaluate();
  await tester.runAsync(() async {
    for (final imageElement in imageElements) {
      final widget = imageElement.widget;
      if (widget is Image) {
        await precacheImage(widget.image, imageElement);
      }
    }
    for (final container in containerElements) {
      final widget = container.widget as DecoratedBox;
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        if (decoration.image != null) {
          await precacheImage(decoration.image!.image, container);
        }
      }
    }
  });
}

Future<void> _onlyPumpAndSettle(WidgetTester tester) async =>
    tester.pumpAndSettle();

/// Captures a screenshot of the widget and saves it to a file
Future<void> captureScreenshot(
  WidgetTester tester,
  String name, {
  Finder? finder,
  CustomPump? customPump,
  required DeviceFileNameFactory fileNameFactory,
  required Device device,
}) async {
  assert(
    !name.endsWith('.png'),
    'Screenshot names should not include file type',
  );

  final pumpAfterPrime = customPump ?? _onlyPumpAndSettle;
  final actualFinder = finder ?? find.byWidgetPredicate((w) => true).first;
  final fileName = fileNameFactory(name, device);

  await tester.waitForAssets();
  await pumpAfterPrime(tester);

  // Capture the image
  final imageFuture = captureImage(actualFinder.evaluate().first);

  // Save the image to a file
  final relativeDirectory = Directory.current;
  final file = File(fileName);
  await tester.runAsync(() async {
    final ui.Image image = await imageFuture;
    try {
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        return 'could not encode screenshot.';
      } else {
        await file.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
      }
    } catch (e) {
      print(e);
    }
  });
}

/// Render the closest [RepaintBoundary] of the [element] into an image.
///
/// See also:
///
///  * [OffsetLayer.toImage] which is the actual method being called.
Future<ui.Image> captureImage(Element element) {
  assert(element.renderObject != null);
  RenderObject renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    renderObject = renderObject.parent!;
  }
  assert(!renderObject.debugNeedsPaint);
  final OffsetLayer layer = renderObject.debugLayer! as OffsetLayer;
  return layer.toImage(renderObject.paintBounds);
}
