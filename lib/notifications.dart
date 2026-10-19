import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lajf_app/life_data.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LifeNotifications {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = await android?.requestNotificationsPermission() ?? false;
    if (!allowed) return false;
    if (await android?.canScheduleExactNotifications() != true) {
      await android?.requestExactAlarmsPermission();
    }
    return true;
  }

  Future<void> scheduleAll(LifeData data) async {
    if (!Platform.isAndroid || !data.ready || data.loadError != null) return;
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() != true) return;
    final exact = await android?.canScheduleExactNotifications() == true;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'lajf_reminders',
        'LajfApp reminders',
        channelDescription: 'Planner tasks and university deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final now = DateTime.now();
    final notifications = <_ScheduledReminder>[];
    for (var dayOffset = 0; dayOffset <= 60; dayOffset++) {
      final day = dayOnly(now).add(Duration(days: dayOffset));
      for (final kind in TaskKind.values) {
        for (final occurrence in data.occurrences(kind, day)) {
          if (occurrence.completed ||
              occurrence.task.repeat == TaskRepeat.none) {
            continue;
          }
          for (final minutes in occurrence.task.reminderMinutes) {
            final when = occurrence.at.subtract(Duration(minutes: minutes));
            if (when.isAfter(now)) {
              notifications.add(
                _ScheduledReminder(
                  when,
                  occurrence.task.kind == TaskKind.university
                      ? 'University reminder'
                      : 'Planner reminder',
                  '${occurrence.task.title} · ${timeLabel(occurrence.at)}',
                ),
              );
            }
          }
        }
      }
    }
    // Schedule one-time deadlines separately, including postponed ones.
    for (final task in data.tasks.where(
      (task) => task.repeat == TaskRepeat.none,
    )) {
      final state = task.progress[dayKey(task.at)];
      if (state?.deletedReason != null || state?.completedOn != null) continue;
      final due = state?.postponedTo == null
          ? task.at
          : DateTime(
              state!.postponedTo!.year,
              state.postponedTo!.month,
              state.postponedTo!.day,
              task.at.hour,
              task.at.minute,
            );
      for (final minutes in task.reminderMinutes) {
        final when = due.subtract(Duration(minutes: minutes));
        if (when.isAfter(now)) {
          notifications.add(
            _ScheduledReminder(
              when,
              task.kind == TaskKind.university
                  ? 'University reminder'
                  : 'Planner reminder',
              '${task.title} · ${timeLabel(due)}',
            ),
          );
        }
      }
    }
    notifications.sort((a, b) => a.when.compareTo(b.when));
    var id = 1;
    for (final reminder in notifications.take(500)) {
      await _plugin.zonedSchedule(
        id: id++,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        notificationDetails: details,
        androidScheduleMode: mode,
      );
    }
  }
}

class _ScheduledReminder {
  const _ScheduledReminder(this.when, this.title, this.body);
  final DateTime when;
  final String title;
  final String body;
}
