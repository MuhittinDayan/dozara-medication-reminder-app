import 'notification_service.dart';

abstract class NotificationScheduler {
  Future<void> rescheduleAllNotifications();
}

class FlutterNotificationScheduler implements NotificationScheduler {
  const FlutterNotificationScheduler();

  @override
  Future<void> rescheduleAllNotifications() {
    return NotificationService.rescheduleAllNotifications();
  }
}
