import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'background_monitor_bridge.dart';
import 'core_service.dart';
import 'notification_service.dart';

class AlertPollingService {
  static Timer? _timer;
  static int _lastSeenId = 0;
  static int _lastSeenDoorEventId = 0;

  static const String _lastSeenAlertIdKey = 'last_seen_alert_id';
  static const String _lastSeenDoorEventIdKey = 'last_seen_door_event_id';
  static const String _alertsPrimedKey = 'alerts_polling_initialized';
  static const String _doorEventsPrimedKey = 'door_events_polling_initialized';

  static Future<void> startPolling() async {
    if (Platform.isAndroid) {
      await _startAndroidBackgroundMonitor();
      return;
    }

    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    _lastSeenId = prefs.getInt(_lastSeenAlertIdKey) ?? 0;
    _lastSeenDoorEventId = prefs.getInt(_lastSeenDoorEventIdKey) ?? 0;

    await _primeSeenState();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkNewAlerts();
    });

    await _checkNewAlerts();
  }

  static Future<void> stopPolling({bool resetState = true}) async {
    _timer?.cancel();
    _timer = null;

    if (Platform.isAndroid) {
      await BackgroundMonitorBridge.stop(resetState: resetState);
    }

    if (resetState) {
      await _resetSeenState();
    }
  }

  static Future<void> _startAndroidBackgroundMonitor() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = await ApiClient.accessToken;
    final refreshToken = await ApiClient.refreshToken;

    await BackgroundMonitorBridge.bootstrap(
      baseUrl: AppConfig.baseUrl,
      accessToken: accessToken,
      refreshToken: refreshToken,
      lastSeenAlertId: prefs.getInt(_lastSeenAlertIdKey) ?? 0,
      lastSeenDoorEventId: prefs.getInt(_lastSeenDoorEventIdKey) ?? 0,
    );

    await BackgroundMonitorBridge.start();
  }

  static Future<void> _primeSeenState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!(prefs.getBool(_alertsPrimedKey) ?? false)) {
      final response = await CoreService.getAlerts(
        acknowledged: false,
        limit: 5,
      );
      if (response.success) {
        final List<dynamic> alerts = response.data['alerts'] ?? [];
        if (alerts.isNotEmpty) {
          final baselineId = alerts
              .map((alert) => alert['id'] as int)
              .reduce((current, next) => current > next ? current : next);
          _lastSeenId = baselineId;
          await prefs.setInt(_lastSeenAlertIdKey, baselineId);
        }
        await prefs.setBool(_alertsPrimedKey, true);
      }
    }

    if (!(prefs.getBool(_doorEventsPrimedKey) ?? false)) {
      final response = await CoreService.getDoorEvents(limit: 5);
      if (response.success) {
        final List<dynamic> events = response.data['door_events'] ?? [];
        if (events.isNotEmpty) {
          final baselineId = events
              .map((event) => event['id'] as int)
              .reduce((current, next) => current > next ? current : next);
          _lastSeenDoorEventId = baselineId;
          await prefs.setInt(_lastSeenDoorEventIdKey, baselineId);
        }
        await prefs.setBool(_doorEventsPrimedKey, true);
      }
    }
  }

  static Future<void> _checkNewAlerts() async {
    try {
      print('🔍 [AlertPolling] Checking for new alerts... Last seen ID: $_lastSeenId');

      final response = await CoreService.getAlerts(
        acknowledged: false,
        limit: 5,
      );

      print('📡 [AlertPolling] Response success: ${response.success}');
      if (!response.success) {
        print('❌ [AlertPolling] API Error: ${response.message}');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_alertsPrimedKey) ?? false)) {
        await _primeSeenState();
        return;
      }

      final List<dynamic> alerts = response.data['alerts'] ?? [];
      print('📊 [AlertPolling] Found ${alerts.length} unacknowledged alerts');

      if (alerts.isEmpty) return;

      int maxId = _lastSeenId;
      bool foundNew = false;
      final sortedAlerts = List<dynamic>.from(alerts)
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      for (var alert in sortedAlerts) {
        final id = alert['id'] as int;
        print('🔔 [AlertPolling] Alert ID: $id (last seen: $_lastSeenId)');

        if (id > _lastSeenId) {
          foundNew = true;
          if (id > maxId) maxId = id;

          print('✨ [AlertPolling] NEW ALERT! Showing notification...');

          if (alert['title']?.toString().toLowerCase().contains('stranger') == true ||
              alert['message']?.toString().toLowerCase().contains('stranger') == true) {
            final deviceName = alert['device_name'] ?? 'Security Camera';
            await NotificationService.showStrangerAlert(
              id: id,
              deviceName: deviceName,
              imageUrl: alert['image_url'],
            );
          } else {
            await NotificationService.showNotification(
              id: id,
              title: '🚨 ${alert['title']}',
              body: alert['message'] ?? 'New security alert detected.',
              type: NotificationType.security,
            );
          }
        }
      }

      if (foundNew) {
        _lastSeenId = maxId;
        await prefs.setInt(_lastSeenAlertIdKey, _lastSeenId);
        print('💾 [AlertPolling] Updated last seen ID to: $_lastSeenId');
      }

      await _checkDoorEvents();
    } catch (e) {
      print('❌ [AlertPolling] Exception: $e');
    }
  }

  static Future<void> _checkDoorEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSeenDoorEventId = prefs.getInt(_lastSeenDoorEventIdKey) ?? 0;

      if (!(prefs.getBool(_doorEventsPrimedKey) ?? false)) {
        await _primeSeenState();
        return;
      }

      print('🚪 [AlertPolling] Checking for door events... Last seen ID: $_lastSeenDoorEventId');

      final response = await CoreService.getDoorEvents(limit: 5);

      if (!response.success) {
        print('❌ [AlertPolling] Door events API Error: ${response.message}');
        return;
      }

      final List<dynamic> events = response.data['door_events'] ?? [];
      print('📊 [AlertPolling] Found ${events.length} door events');

      if (events.isEmpty) return;

      int maxId = _lastSeenDoorEventId;
      bool foundNew = false;

      final sortedEvents = List<dynamic>.from(events);
      sortedEvents.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      for (var event in sortedEvents) {
        final id = event['id'] as int;
        if (id > _lastSeenDoorEventId) {
          foundNew = true;
          if (id > maxId) maxId = id;

          final doorName = event['door_name'] ?? event['device_name'] ?? 'Door';
          final status = event['status'] == 'open' ? 'opened' : 'closed';

          print('🚪 [AlertPolling] New door event: $doorName $status');

          await NotificationService.showDoorEvent(
            id: 100000 + id,
            doorName: doorName,
            action: status,
          );
        }
      }

      if (foundNew) {
        _lastSeenDoorEventId = maxId;
        await prefs.setInt(_lastSeenDoorEventIdKey, _lastSeenDoorEventId);
        print('💾 [AlertPolling] Updated last seen door event ID to: $_lastSeenDoorEventId');
      }
    } catch (e) {
      print('❌ [AlertPolling] Door events exception: $e');
    }
  }

  static Future<void> _resetSeenState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSeenAlertIdKey);
    await prefs.remove(_lastSeenDoorEventIdKey);
    await prefs.remove(_alertsPrimedKey);
    await prefs.remove(_doorEventsPrimedKey);
    _lastSeenId = 0;
    _lastSeenDoorEventId = 0;
  }
}
