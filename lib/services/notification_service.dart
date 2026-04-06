import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/epg_reminder_service.dart';

/// Singleton service for system notifications (EPG reminders, etc.).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification plugin with platform-specific settings.
  /// Fails silently — app works without notifications.
  Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
      );
      const macOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
      );
      const linux = LinuxInitializationSettings(defaultActionName: 'Open');

      const settings = InitializationSettings(
        android: android,
        iOS: ios,
        macOS: macOS,
        linux: linux,
      );

      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // Notification init failed — app continues without system notifications
      _initialized = false;
    }
  }

  /// Show a system notification for an upcoming EPG program.
  /// No-op if notification plugin is not initialized.
  Future<void> showEpgReminder(EpgReminder reminder) async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'epg_reminders',
      'EPG Reminders',
      channelDescription: 'Notifications for upcoming TV programs',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      id: reminder.id.hashCode,
      title: 'Rappel EPG',
      body: '${reminder.programTitle} — ${reminder.channelName}',
      notificationDetails: details,
    );
  }
}
