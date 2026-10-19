import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int daysApart(DateTime first, DateTime second) => DateTime.utc(
  second.year,
  second.month,
  second.day,
).difference(DateTime.utc(first.year, first.month, first.day)).inDays;

String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String euro(int cents) =>
    '${cents < 0 ? '-' : ''}€${(cents.abs() / 100).toStringAsFixed(2)}';

int? parseEuro(String value) {
  final match = RegExp(r'^\s*(\d+)(?:[.,](\d{1,2}))?\s*$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final decimal = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + (decimal.isEmpty ? 0 : int.parse(decimal));
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class ExpenseCategory {
  ExpenseCategory(this.id, this.name, this.color, {this.comment = ''});
  final String id;
  final String name;
  final int color;
  final String comment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'comment': comment,
  };
  factory ExpenseCategory.fromJson(Map<String, dynamic> data) =>
      ExpenseCategory(
        data['id'] as String,
        data['name'] as String,
        data['color'] as int,
        comment: data['comment'] as String? ?? '',
      );
}

class MoneyEntry {
  MoneyEntry({
    required this.id,
    required this.name,
    required this.cents,
    required this.at,
    required this.isIncome,
    this.categoryId,
    this.recurringId,
    this.comment = '',
  });
  final String id;
  final String name;
  final int cents;
  final DateTime at;
  final bool isIncome;
  final String? categoryId;
  final String? recurringId;
  final String comment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cents': cents,
    'at': at.toIso8601String(),
    'isIncome': isIncome,
    'categoryId': categoryId,
    'recurringId': recurringId,
    'comment': comment,
  };
  factory MoneyEntry.fromJson(Map<String, dynamic> data) => MoneyEntry(
    id: data['id'] as String,
    name: data['name'] as String,
    cents: data['cents'] as int,
    at: DateTime.parse(data['at'] as String),
    isIncome: data['isIncome'] as bool,
    categoryId: data['categoryId'] as String?,
    recurringId: data['recurringId'] as String?,
    comment: data['comment'] as String? ?? '',
  );
}

class RecurringExpense {
  RecurringExpense({
    required this.id,
    required this.name,
    required this.cents,
    required this.categoryId,
    required this.day,
    required this.startMonth,
    this.active = true,
    this.comment = '',
  });
  final String id;
  final String name;
  final int cents;
  final String categoryId;
  final int day;
  final String startMonth;
  final bool active;
  final String comment;

  RecurringExpense copyWith({bool? active}) => RecurringExpense(
    id: id,
    name: name,
    cents: cents,
    categoryId: categoryId,
    day: day,
    startMonth: startMonth,
    active: active ?? this.active,
    comment: comment,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cents': cents,
    'categoryId': categoryId,
    'day': day,
    'startMonth': startMonth,
    'active': active,
    'comment': comment,
  };
  factory RecurringExpense.fromJson(Map<String, dynamic> data) =>
      RecurringExpense(
        id: data['id'] as String,
        name: data['name'] as String,
        cents: data['cents'] as int,
        categoryId: data['categoryId'] as String,
        day: data['day'] as int,
        startMonth: data['startMonth'] as String,
        active: data['active'] as bool? ?? true,
        comment: data['comment'] as String? ?? '',
      );
}

enum TaskKind { planner, university }

enum TaskRepeat { none, daily, weekly }

class TaskProgress {
  TaskProgress({this.completedOn, this.postponedTo, this.deletedReason});
  DateTime? completedOn;
  DateTime? postponedTo;
  String? deletedReason;

  Map<String, dynamic> toJson() => {
    'completedOn': completedOn?.toIso8601String(),
    'postponedTo': postponedTo?.toIso8601String(),
    'deletedReason': deletedReason,
  };
  factory TaskProgress.fromJson(Map<String, dynamic> data) => TaskProgress(
    completedOn: data['completedOn'] == null
        ? null
        : DateTime.parse(data['completedOn'] as String),
    postponedTo: data['postponedTo'] == null
        ? null
        : DateTime.parse(data['postponedTo'] as String),
    deletedReason: data['deletedReason'] as String?,
  );
}

class LifeTask {
  LifeTask({
    required this.id,
    required this.title,
    required this.at,
    required this.kind,
    required this.repeat,
    required this.reminderMinutes,
    this.repeatUntil,
    this.comment = '',
    Map<String, TaskProgress>? progress,
  }) : progress = progress ?? {};
  final String id;
  final String title;
  final DateTime at;
  final TaskKind kind;
  final TaskRepeat repeat;
  final List<int> reminderMinutes;
  final DateTime? repeatUntil;
  final String comment;
  final Map<String, TaskProgress> progress;

  LifeTask withRepeatUntil(DateTime? date) => LifeTask(
    id: id,
    title: title,
    at: at,
    kind: kind,
    repeat: repeat,
    reminderMinutes: reminderMinutes,
    repeatUntil: date,
    comment: comment,
    progress: progress,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'at': at.toIso8601String(),
    'kind': kind.name,
    'repeat': repeat.name,
    'reminderMinutes': reminderMinutes,
    'repeatUntil': repeatUntil?.toIso8601String(),
    'comment': comment,
    'progress': progress.map((key, value) => MapEntry(key, value.toJson())),
  };
  factory LifeTask.fromJson(Map<String, dynamic> data) => LifeTask(
    id: data['id'] as String,
    title: data['title'] as String,
    at: DateTime.parse(data['at'] as String),
    kind: TaskKind.values.byName(data['kind'] as String),
    repeat: TaskRepeat.values.byName(data['repeat'] as String),
    reminderMinutes: (data['reminderMinutes'] as List<dynamic>).cast<int>(),
    repeatUntil: data['repeatUntil'] == null
        ? null
        : DateTime.parse(data['repeatUntil'] as String),
    comment: data['comment'] as String? ?? '',
    progress: (data['progress'] as Map<String, dynamic>).map(
      (key, value) =>
          MapEntry(key, TaskProgress.fromJson(value as Map<String, dynamic>)),
    ),
  );
}

class TaskOccurrence {
  TaskOccurrence(this.task, this.origin, this.at, this.progress);
  final LifeTask task;
  final String origin;
  final DateTime at;
  final TaskProgress? progress;
  bool get completed => progress?.completedOn != null;
  bool get deleted => progress?.deletedReason != null;
}

class GymDay {
  GymDay(this.type, this.done, {this.comment = ''});
  final String type;
  final bool done;
  final String comment;
  Map<String, dynamic> toJson() => {
    'type': type,
    'done': done,
    'comment': comment,
  };
  factory GymDay.fromJson(Map<String, dynamic> data) => GymDay(
    data['type'] as String,
    data['done'] as bool? ?? false,
    comment: data['comment'] as String? ?? '',
  );
}

class LifeData extends ChangeNotifier {
  LifeData({File? file}) : _providedFile = file;
  final File? _providedFile;
  Future<void> _writeQueue = Future.value();

  bool ready = false;
  String? loadError;
  final categories = <ExpenseCategory>[
    ExpenseCategory('food', 'Food', 0xFF8FE3B0),
    ExpenseCategory('transport', 'Transport', 0xFF87B7FF),
    ExpenseCategory('bills', 'Bills', 0xFFFFB876),
    ExpenseCategory('health', 'Health', 0xFFE59CD6),
    ExpenseCategory('fun', 'Fun', 0xFFB5A6FF),
    ExpenseCategory('other', 'Other', 0xFFB8BECC),
  ];
  final money = <MoneyEntry>[];
  final recurringExpenses = <RecurringExpense>[];
  final skippedRecurringIds = <String>{};
  final tasks = <LifeTask>[];
  final gym = <String, GymDay>{};

  Future<File> _file() async {
    if (_providedFile != null) return _providedFile;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}life_data.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (data['categories'] is List) {
          categories
            ..clear()
            ..addAll(
              (data['categories'] as List<dynamic>).map(
                (e) => ExpenseCategory.fromJson(e as Map<String, dynamic>),
              ),
            );
        }
        money
          ..clear()
          ..addAll(
            ((data['money'] as List<dynamic>?) ?? []).map(
              (e) => MoneyEntry.fromJson(e as Map<String, dynamic>),
            ),
          );
        recurringExpenses
          ..clear()
          ..addAll(
            ((data['recurringExpenses'] as List<dynamic>?) ?? []).map(
              (e) => RecurringExpense.fromJson(e as Map<String, dynamic>),
            ),
          );
        skippedRecurringIds
          ..clear()
          ..addAll(
            ((data['skippedRecurringIds'] as List<dynamic>?) ?? [])
                .cast<String>(),
          );
        tasks
          ..clear()
          ..addAll(
            ((data['tasks'] as List<dynamic>?) ?? []).map(
              (e) => LifeTask.fromJson(e as Map<String, dynamic>),
            ),
          );
        gym
          ..clear()
          ..addAll(
            ((data['gym'] as Map<String, dynamic>?) ?? {}).map(
              (key, value) =>
                  MapEntry(key, GymDay.fromJson(value as Map<String, dynamic>)),
            ),
          );
      }
      ready = true;
      notifyListeners();
      await generateRecurringExpenses();
    } catch (_) {
      loadError = 'Could not read saved data. Nothing was overwritten.';
      ready = true;
      notifyListeners();
    }
  }

  Map<String, dynamic> _json() => {
    'version': 1,
    'categories': categories.map((e) => e.toJson()).toList(),
    'money': money.map((e) => e.toJson()).toList(),
    'recurringExpenses': recurringExpenses.map((e) => e.toJson()).toList(),
    'skippedRecurringIds': skippedRecurringIds.toList(),
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'gym': gym.map((key, value) => MapEntry(key, value.toJson())),
  };

  Future<void> persist() {
    if (loadError != null) return Future.error(StateError(loadError!));
    notifyListeners();
    final snapshot = jsonEncode(_json());
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      final file = await _file();
      await file.writeAsString(snapshot, flush: true);
    });
    return _writeQueue;
  }

  Future<void> generateRecurringExpenses([DateTime? clock]) async {
    if (loadError != null) return;
    final today = dayOnly(clock ?? DateTime.now());
    var changed = false;
    for (final plan in recurringExpenses.where((e) => e.active)) {
      final parts = plan.startMonth.split('-').map(int.parse).toList();
      var year = parts[0];
      var month = parts[1];
      while (year < today.year ||
          (year == today.year && month <= today.month)) {
        final date = DateTime(year, month, plan.day);
        final actual = date.month == month
            ? date
            : DateTime(year, month + 1, 0);
        final key = '${plan.id}-${dayKey(actual).substring(0, 7)}';
        if (!actual.isAfter(today) &&
            !skippedRecurringIds.contains(key) &&
            !money.any((e) => e.recurringId == key)) {
          money.add(
            MoneyEntry(
              id: newId() + key,
              name: plan.name,
              cents: plan.cents,
              at: actual,
              isIncome: false,
              categoryId: plan.categoryId,
              recurringId: key,
              comment: plan.comment,
            ),
          );
          changed = true;
        }
        month++;
        if (month == 13) {
          month = 1;
          year++;
        }
      }
    }
    if (changed) await persist();
  }

  int balanceThrough(DateTime month) {
    final end = DateTime(month.year, month.month + 1);
    return money
        .where((e) => e.at.isBefore(end))
        .fold(0, (total, e) => total + (e.isIncome ? e.cents : -e.cents));
  }

  int spentInMonth(DateTime month) => money
      .where(
        (e) =>
            !e.isIncome && e.at.year == month.year && e.at.month == month.month,
      )
      .fold(0, (total, e) => total + e.cents);

  int addedInMonth(DateTime month) => money
      .where(
        (e) =>
            e.isIncome && e.at.year == month.year && e.at.month == month.month,
      )
      .fold(0, (total, e) => total + e.cents);

  int spentInYear(int year) => money
      .where((e) => !e.isIncome && e.at.year == year)
      .fold(0, (total, e) => total + e.cents);

  int get weeklyRemaining {
    final now = DateTime.now();
    final monday = dayOnly(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    final spent = money
        .where(
          (e) =>
              !e.isIncome &&
              !e.at.isBefore(monday) &&
              e.at.isBefore(nextMonday),
        )
        .fold<int>(0, (total, e) => total + e.cents);
    return 7000 - spent;
  }

  ExpenseCategory category(String? id) => categories.firstWhere(
    (category) => category.id == id,
    orElse: () => categories.last,
  );

  List<TaskOccurrence> occurrences(
    TaskKind kind,
    DateTime day, {
    bool includeHistory = false,
  }) {
    final date = dayOnly(day);
    final key = dayKey(date);
    final result = <TaskOccurrence>[];
    for (final task in tasks.where((task) => task.kind == kind)) {
      final fromStart = daysApart(task.at, date);
      final natural =
          fromStart >= 0 &&
          (task.repeatUntil == null ||
              !date.isAfter(dayOnly(task.repeatUntil!))) &&
          (task.repeat == TaskRepeat.daily ||
              (task.repeat == TaskRepeat.weekly && fromStart % 7 == 0) ||
              (task.repeat == TaskRepeat.none && fromStart == 0));
      if (natural) {
        final progress = task.progress[key];
        if (progress?.postponedTo == null || includeHistory) {
          if (progress?.deletedReason == null || includeHistory) {
            result.add(
              TaskOccurrence(
                task,
                key,
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  task.at.hour,
                  task.at.minute,
                ),
                progress,
              ),
            );
          }
        }
      }
      for (final entry in task.progress.entries) {
        final moved = entry.value.postponedTo;
        if (moved != null &&
            dayKey(moved) == key &&
            entry.key != key &&
            entry.value.deletedReason == null) {
          result.add(
            TaskOccurrence(
              task,
              entry.key,
              DateTime(
                date.year,
                date.month,
                date.day,
                task.at.hour,
                task.at.minute,
              ),
              entry.value,
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  Future<void> setCompleted(TaskOccurrence occurrence) async {
    final state = occurrence.task.progress.putIfAbsent(
      occurrence.origin,
      TaskProgress.new,
    );
    state.completedOn = state.completedOn == null ? DateTime.now() : null;
    await persist();
  }

  Future<void> postpone(TaskOccurrence occurrence, DateTime to) async {
    final state = occurrence.task.progress.putIfAbsent(
      occurrence.origin,
      TaskProgress.new,
    );
    state.postponedTo = dayOnly(to);
    state.completedOn = null;
    state.deletedReason = null;
    await persist();
  }

  Future<void> removeOccurrence(
    TaskOccurrence occurrence,
    String reason,
  ) async {
    final state = occurrence.task.progress.putIfAbsent(
      occurrence.origin,
      TaskProgress.new,
    );
    state.deletedReason = reason;
    await persist();
  }
}
