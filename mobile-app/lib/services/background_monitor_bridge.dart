import 'dart:io';

import 'package:flutter/services.dart';

class BackgroundMonitorBridge {
  static const MethodChannel _channel =
      MethodChannel('com.homesecurity.home_security/background_monitor');

  static bool get _isSupported => Platform.isAndroid;

  static Future<void> bootstrap({
    required String baseUrl,
    required int lastSeenAlertId,
    required int lastSeenDoorEventId,
    String? accessToken,
    String? refreshToken,
  }) async {
    if (!_isSupported) return;

    await _channel.invokeMethod('bootstrap', <String, dynamic>{
      'baseUrl': baseUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'lastSeenAlertId': lastSeenAlertId,
      'lastSeenDoorEventId': lastSeenDoorEventId,
    });
  }

  static Future<void> updateAuth({
    required String baseUrl,
    String? accessToken,
    String? refreshToken,
  }) async {
    if (!_isSupported) return;

    await _channel.invokeMethod('updateAuth', <String, dynamic>{
      'baseUrl': baseUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    });
  }

  static Future<void> clearAuth() async {
    if (!_isSupported) return;
    await _channel.invokeMethod('clearAuth');
  }

  static Future<void> start() async {
    if (!_isSupported) return;
    await _channel.invokeMethod('start');
  }

  static Future<void> stop({bool resetState = false}) async {
    if (!_isSupported) return;
    await _channel.invokeMethod('stop', <String, dynamic>{
      'resetState': resetState,
    });
  }
}
