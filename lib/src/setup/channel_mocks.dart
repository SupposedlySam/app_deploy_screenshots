import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stubs for platform channels that commonly fail in widget tests.
abstract final class ChannelMocks {
  /// Sets up common platform channel mocks to prevent test failures
  static void install({bool verbose = false}) {
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
        .setMockMessageHandler('receive_sharing_intent/events-media', (
          ByteData? message,
        ) async {
          if (message != null) {
            final methodCall = codec.decodeMethodCall(message);
            if (methodCall.method == 'listen') {
              return codec.encodeSuccessEnvelope('[]');
            } else if (methodCall.method == 'cancel') {
              return codec.encodeSuccessEnvelope(null);
            }
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('receive_sharing_intent/events-text', (
          ByteData? message,
        ) async {
          if (message != null) {
            final methodCall = codec.decodeMethodCall(message);
            if (methodCall.method == 'listen') {
              return codec.encodeSuccessEnvelope('');
            } else if (methodCall.method == 'cancel') {
              return codec.encodeSuccessEnvelope(null);
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
}
