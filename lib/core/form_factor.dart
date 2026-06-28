import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device form factor — drives the 10-foot UI density and D-pad focus
/// navigation. Mirrors the split that the tvOS Swift app gets for free
/// from the platform: here we have to detect it at runtime because the
/// same Android APK serves both phones and Android TV.
enum FormFactor { phone, tablet, desktop, tv }

/// Form-factor detection.
///
/// Android TV is detected via the `android.software.leanback` system
/// feature (the same feature the `<uses-feature>` manifest entry and the
/// `LEANBACK_LAUNCHER` intent filter key off). The lookup needs a
/// platform channel, so it's resolved once at startup in
/// [FormFactorInfo.ensureInitialized] and then read synchronously via
/// [isAndroidTv] / [current] from the UI.
class FormFactorInfo {
  FormFactorInfo._();

  static bool _initialized = false;
  static bool _isAndroidTv = false;

  /// True on Android TV / leanback devices. Always false before
  /// [ensureInitialized] has run, and on every non-Android platform.
  static bool get isAndroidTv => _isAndroidTv;

  /// Coarse form factor. Desktop covers macOS / Windows / Linux; `tv`
  /// is Android TV; everything else mobile reports as `phone` (we don't
  /// currently distinguish tablets — kept in the enum for future use).
  static FormFactor get current {
    if (_isAndroidTv) return FormFactor.tv;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return FormFactor.desktop;
    }
    return FormFactor.phone;
  }

  /// Resolve the Android TV flag. Safe to call on any platform — it's a
  /// no-op (and leaves [isAndroidTv] false) off Android. Idempotent.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _isAndroidTv =
          info.systemFeatures.contains('android.software.leanback') ||
          info.systemFeatures.contains('android.hardware.type.television');
    } catch (e) {
      // Detection failure must not block startup — fall back to phone UI.
      debugPrint('FormFactorInfo: leanback detection failed: $e');
    }
  }
}
