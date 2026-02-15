import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/app_logger.dart';

/// JS interop bindings for webOS device info.
@JS('window.webOSVersion')
external String? get _jsWebOSVersion;

@JS('window.isWebOS')
external bool? get _jsIsWebOS;

@JS('window.webOSDeviceInfo')
external JSObject? get _jsWebOSDeviceInfo;

/// Service for webOS-specific functionality and feature detection.
///
/// Provides methods to detect TV capabilities and retrieve device information
/// using JavaScript interop with the webOS system APIs.
class WebOSService {
  static WebOSService? _instance;

  WebOSService._();

  static WebOSService get instance {
    _instance ??= WebOSService._();
    return _instance!;
  }

  /// Whether the app is running on webOS.
  bool get isWebOS => kIsWeb && _detectWebOS();

  bool? _webOSCached;

  bool _detectWebOS() {
    if (_webOSCached != null) return _webOSCached!;
    try {
      _webOSCached = _jsIsWebOS ?? false;
    } catch (_) {
      _webOSCached = false;
    }
    return _webOSCached!;
  }

  /// webOS device info (populated on init).
  String? modelName;
  String? sdkVersion;
  String? firmwareVersion;
  bool is4K = false;

  /// Initialize webOS service and detect device capabilities.
  Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      // Read webOS version set by index.html detection script
      sdkVersion = _jsWebOSVersion;

      // Try to read extended device info if available
      final deviceInfo = _jsWebOSDeviceInfo;
      if (deviceInfo != null) {
        modelName = (deviceInfo as JSObject).getProperty('modelName'.toJS)?.toString();
        firmwareVersion = (deviceInfo as JSObject).getProperty('firmwareVersion'.toJS)?.toString();
        final uhdValue = (deviceInfo as JSObject).getProperty('UHD'.toJS)?.toString();
        is4K = uhdValue == 'true';
      }

      appLogger.i('WebOS initialized - model: $modelName, SDK: $sdkVersion, 4K: $is4K');
    } catch (e) {
      appLogger.w('WebOS service initialization failed (non-webOS browser?)', error: e);
    }
  }
}
