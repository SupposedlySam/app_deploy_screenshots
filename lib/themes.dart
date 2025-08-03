import 'package:flutter/material.dart';

/// Utilities for creating screenshot-friendly themes that render well in test environments
class ScreenshotThemes {
  ScreenshotThemes._();

  /// Creates a screenshot-optimized theme that works well in test environments
  ///
  /// [brightness] - Light or dark theme brightness
  /// [primaryColor] - Primary app color for branding consistency
  /// [fontFamily] - Custom font family (falls back to system fonts if null)
  /// [useMaterial3] - Whether to use Material 3 design system
  static ThemeData createScreenshotTheme({
    Brightness brightness = Brightness.light,
    Color? primaryColor,
    String? fontFamily,
    bool useMaterial3 = false,
  }) {
    final ColorScheme colorScheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: primaryColor ?? Colors.blue,
            secondary: primaryColor ?? Colors.blue,
          )
        : ColorScheme.dark(
            primary: primaryColor ?? Colors.blue,
            secondary: primaryColor ?? Colors.blue,
          );

    return ThemeData(
      useMaterial3: useMaterial3,
      brightness: brightness,
      colorScheme: colorScheme,

      // Font configuration with fallbacks for test compatibility
      fontFamily: fontFamily,
      fontFamilyFallback: _getSystemFontFallbacks(),

      // Optimize for screenshot clarity
      visualDensity: VisualDensity.standard,

      // Ensure proper text selection visibility
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: colorScheme.primary,
      ),

      // Clear app bar styling for screenshots
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),

      // Consistent button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// Creates a light theme optimized for iOS App Store screenshots
  static ThemeData iosAppStoreLight({
    Color primaryColor = const Color(0xFF007AFF), // iOS Blue
    String? fontFamily,
  }) {
    return createScreenshotTheme(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
      useMaterial3: false, // Use Material 2 for more iOS-like appearance
    );
  }

  /// Creates a dark theme optimized for iOS App Store screenshots
  static ThemeData iosAppStoreDark({
    Color primaryColor = const Color(0xFF0A84FF), // iOS Dark Blue
    String? fontFamily,
  }) {
    return createScreenshotTheme(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
      useMaterial3: false,
    );
  }

  /// Creates a theme optimized for Android Play Store screenshots
  static ThemeData androidPlayStore({
    Color primaryColor = const Color(0xFF1976D2), // Material Blue
    String? fontFamily,
    bool useMaterial3 = true,
  }) {
    return createScreenshotTheme(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      fontFamily: fontFamily,
      useMaterial3: useMaterial3,
    );
  }

  /// System font fallbacks for maximum test compatibility
  static List<String> _getSystemFontFallbacks() {
    return const [
      'SF Pro Display', // iOS
      'SF Pro Text', // iOS
      'Helvetica Neue', // macOS
      'Roboto', // Android
      'Segoe UI', // Windows
      'Ubuntu', // Linux
      'Arial', // Universal fallback
      'sans-serif', // Web fallback
    ];
  }
}

/// Extension methods for easily applying screenshot themes to widgets
extension ScreenshotThemeExtension on Widget {
  /// Wraps this widget with a MaterialApp using a screenshot-optimized theme
  ///
  /// This extension provides an easy way to apply screenshot-friendly themes
  /// that render properly in test environments.
  ///
  /// [theme] - The theme to use (defaults to light iOS App Store theme)
  /// [localizationsDelegates] - Localization delegates for the app
  /// [supportedLocales] - List of supported locales
  /// [debugShowCheckedModeBanner] - Whether to show the debug banner
  Widget withScreenshotTheme({
    ThemeData? theme,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale>? supportedLocales,
    bool debugShowCheckedModeBanner = false,
  }) {
    return MaterialApp(
      theme: theme ?? ScreenshotThemes.iosAppStoreLight(),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales ?? const [Locale('en', 'US')],
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      home: this,
    );
  }
}
