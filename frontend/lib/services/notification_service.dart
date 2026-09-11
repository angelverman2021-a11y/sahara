import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/announcement.dart';
import '../models/person.dart';
import '../screens/broadcast_screen.dart';
import '../screens/chat_screen.dart';
import 'emergency_service.dart';

/// Offline, lightweight Android notification service for Sahara Emergency Mesh.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.sahra/native');

  GlobalKey<NavigatorState>? _navigatorKey;
  EmergencyService? _emergencyService;

  void initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required EmergencyService emergencyService,
  }) {
    _navigatorKey = navigatorKey;
    _emergencyService = emergencyService;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationClicked') {
        final arguments = call.arguments;
        if (arguments is Map) {
          final stringMap = arguments.map((key, value) => MapEntry(key.toString(), value.toString()));
          handleNotificationAction(stringMap);
        }
      }
    });
  }

  /// Checks if Android POST_NOTIFICATIONS permission is granted (API 33+).
  Future<bool> checkPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkNotificationPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Contextually requests notification permission.
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Shows high-priority Emergency Broadcast notification with sound and loud vibration.
  Future<void> showEmergencyBroadcastNotification({
    required String title,
    required String message,
    required AnnouncementSeverity severity,
    String? id,
  }) async {
    try {
      String sevStr = 'warning';
      switch (severity) {
        case AnnouncementSeverity.evacuation:
          sevStr = 'evacuation';
          break;
        case AnnouncementSeverity.warning:
          sevStr = 'warning';
          break;
        case AnnouncementSeverity.advisory:
          sevStr = 'advisory';
          break;
      }

      await _channel.invokeMethod('showEmergencyNotification', {
        'title': title,
        'message': message,
        'severity': sevStr,
        'id': id ?? 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (_) {}
  }

  /// Shows incoming family message notification with sound and vibration.
  Future<void> showFamilyMessageNotification({
    required String senderName,
    required String content,
    required String personId,
  }) async {
    try {
      await _channel.invokeMethod('showFamilyMessageNotification', {
        'senderName': senderName,
        'content': content,
        'personId': personId,
      });
    } catch (_) {}
  }

  /// Retrieves initial notification intent payload if app was launched via notification click.
  Future<Map<String, String>?> getInitialNotificationAction() async {
    try {
      final result = await _channel.invokeMethod('getInitialNotification');
      if (result is Map) {
        return result.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return null;
  }

  /// Navigates to relevant destination based on notification action.
  void handleNotificationAction(Map<String, String> data) {
    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    final action = data['action'];
    if (action == 'open_broadcast') {
      navState.push(
        MaterialPageRoute(builder: (_) => const BroadcastScreen()),
      );
    } else if (action == 'open_chat') {
      final personId = data['personId'];
      final service = _emergencyService;
      if (service != null) {
        final person = service.allKnownPeople.firstWhere(
          (p) => p.id == personId,
          orElse: () => service.conversations.firstWhere(
            (p) => p.relation == PersonRelation.family,
            orElse: () => service.conversations.first,
          ),
        );
        navState.push(
          MaterialPageRoute(builder: (_) => ChatScreen(person: person)),
        );
      }
    }
  }
}
