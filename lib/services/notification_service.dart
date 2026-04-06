import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/epg_reminder_service.dart';

/// Singleton service for system notifications (EPG reminders, etc.).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin with platform-specific settings.
  Future<void> init() async {
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
  }

  /// Show a system notification for an upcoming EPG program.
  Future<void> showEpgReminder(EpgReminder reminder) async {
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
