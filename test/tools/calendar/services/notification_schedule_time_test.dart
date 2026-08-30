import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/calendar/services/notification_service.dart';

void main() {
  group('NotificationService.resolveScheduleTime', () {
    final now = DateTime(2026, 8, 25, 12, 0);

    test('תזכורת עתידית — מתוזמנת לזמן התזכורת', () {
      final eventDate = DateTime(2026, 8, 25, 14, 0);
      final result = NotificationService.resolveScheduleTime(
        eventDate: eventDate,
        reminderMinutes: 60,
        now: now,
      );
      expect(result, DateTime(2026, 8, 25, 13, 0));
    });

    test('חלון התזכורת כבר התחיל — נופל לזמן האירוע עצמו (issue #984)', () {
      final eventDate = DateTime(2026, 8, 25, 12, 30);
      final result = NotificationService.resolveScheduleTime(
        eventDate: eventDate,
        reminderMinutes: 60,
        now: now,
      );
      expect(result, eventDate);
    });

    test('אירוע שכבר עבר — אין תזמון', () {
      final eventDate = DateTime(2026, 8, 25, 11, 0);
      final result = NotificationService.resolveScheduleTime(
        eventDate: eventDate,
        reminderMinutes: 30,
        now: now,
      );
      expect(result, isNull);
    });

    test('אירוע בדיוק בזמן הנוכחי — אין תזמון', () {
      final result = NotificationService.resolveScheduleTime(
        eventDate: now,
        reminderMinutes: 60,
        now: now,
      );
      expect(result, isNull);
    });

    test('תזכורת של 0 דקות לאירוע עתידי — מתוזמנת לזמן האירוע', () {
      final eventDate = DateTime(2026, 8, 25, 12, 45);
      final result = NotificationService.resolveScheduleTime(
        eventDate: eventDate,
        reminderMinutes: 0,
        now: now,
      );
      expect(result, eventDate);
    });
  });
}
