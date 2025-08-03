import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_toolkit/golden_toolkit.dart';
import 'themes.dart';

/// Test setup utilities for screenshot testing
class ScreenshotTestSetup {
  ScreenshotTestSetup._();

  /// Comprehensive setup for screenshot tests with font loading and configuration
  ///
  /// This should be called in your `flutter_test_config.dart` or in `setUpAll`
  ///
  /// [loadFonts] - Whether to load custom fonts (recommended: true)
  /// [verbose] - Whether to print detailed setup information
  /// [mockPlatformChannels] - Whether to mock common platform channels
  static Future<void> initialize({
    bool loadFonts = true,
    bool verbose = false,
    bool mockPlatformChannels = true,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    if (verbose) {
      debugPrint('🚀 Initializing screenshot test environment...');
    }

    // Load fonts for better text rendering
    if (loadFonts) {
      await loadAppFonts(verbose: verbose, skipOnError: true);
    }

    // Mock common platform channels that might interfere with tests
    if (mockPlatformChannels) {
      _setupCommonChannelMocks(verbose: verbose);
    }

    // Small delay to ensure everything is initialized
    await Future.delayed(const Duration(milliseconds: 100));

    if (verbose) {
      debugPrint('✅ Screenshot test environment ready!');
    }
  }

  /// Sets up common platform channel mocks to prevent test failures
  static void _setupCommonChannelMocks({bool verbose = false}) {
    if (verbose) {
      debugPrint('📱 Setting up platform channel mocks...');
    }

    // Mock sharing intent plugin (common in many apps)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('receive_sharing_intent/messages'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getInitialMedia':
            return '[]';
          case 'getInitialText':
            return '';
          case 'reset':
            return null;
          default:
            return null;
        }
      },
    );

    // Mock sharing intent event channels
    const codec = StandardMethodCodec();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('receive_sharing_intent/events-media',
            (ByteData? message) async {
      if (message != null) {
        final methodCall = codec.decodeMethodCall(message);
        if (methodCall.method == 'listen') {
          return codec.encodeSuccessEnvelope('[]');
        }
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('receive_sharing_intent/events-text',
            (ByteData? message) async {
      if (message != null) {
        final methodCall = codec.decodeMethodCall(message);
        if (methodCall.method == 'listen') {
          return codec.encodeSuccessEnvelope('');
        }
      }
      return null;
    });

    // Mock shared preferences (common in apps with settings)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAll':
            return <String, dynamic>{};
          default:
            return null;
        }
      },
    );

    if (verbose) {
      debugPrint('  ✅ Platform channel mocks configured');
    }
  }

  /// Creates a widget wrapped with screenshot-optimized configuration
  ///
  /// This is useful for creating consistent test widgets with proper theming
  static Widget createScreenshotWidget(
    Widget child, {
    ThemeData? theme,
    Brightness brightness = Brightness.light,
    Color? primaryColor,
    String? fontFamily,
    List<LocalizationsDelegate>? localizationsDelegates,
    List<Locale>? supportedLocales,
  }) {
    return MaterialApp(
      theme: theme ??
          ScreenshotThemes.createScreenshotTheme(
            brightness: brightness,
            primaryColor: primaryColor,
            fontFamily: fontFamily,
          ),
      home: child,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales ?? const [Locale('en', 'US')],
    );
  }

  /// Ensures a widget is properly loaded and settled before screenshots
  ///
  /// This is more thorough than just `pumpAndSettle()` and handles edge cases
  static Future<void> prepareWidgetForScreenshot(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Wait for assets to load
    await tester.waitForAssets();

    // Pump and settle with timeout
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Additional pump to ensure everything is rendered
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Creates mock data structures commonly needed for screenshot tests
  static ScreenshotMockData createMockData() {
    return ScreenshotMockData();
  }
}

/// Container for common mock data used in screenshot tests
class ScreenshotMockData {
  /// Sample user names for testing
  List<String> get userNames => [
        'Alice Johnson',
        'Bob Smith',
        'Carol Williams',
        'David Brown',
        'Emma Davis',
        'Frank Wilson',
        'Grace Miller',
        'Henry Taylor',
      ];

  /// Sample messages for chat/conversation screenshots
  List<String> get sampleMessages => [
        'Hey! How was your weekend? 😊',
        'It was great! Went hiking with some friends 🏔️',
        'That sounds amazing! Did you take any photos?',
        'Yes! Let me share a few with you 📸',
        'This view is incredible! 😍',
        'Right? The weather was perfect for hiking',
        'I should definitely join you next time!',
        'Absolutely! There are some great trails nearby',
        'Looking forward to it! 🎉',
        'Perfect! Let\'s plan something soon',
      ];

  /// Sample email addresses for testing
  List<String> get emailAddresses => [
        'alice.johnson@example.com',
        'bob.smith@example.com',
        'carol.williams@example.com',
        'david.brown@example.com',
        'emma.davis@example.com',
      ];

  /// Sample timestamps for testing (formatted strings)
  List<String> get timestamps => [
        '2:30 PM',
        '2:32 PM',
        '2:33 PM',
        '2:35 PM',
        '2:40 PM',
        '2:42 PM',
        '2:45 PM',
        '2:47 PM',
        'Yesterday',
        'Monday',
      ];

  /// Sample colors for UI testing
  List<Color> get accentColors => [
        const Color(0xffFAE54B), // Yellow
        const Color(0xff649BFA), // Blue
        const Color(0xffFAB37D), // Orange
        const Color(0xff8770FA), // Purple
        const Color(0xff4AE5A3), // Green
        const Color(0xffFA6B7D), // Red/Pink
      ];
}
