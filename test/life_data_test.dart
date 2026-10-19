import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lajf_app/life_data.dart';

void main() {
  test('budget carries surplus and debt; deposits are manual', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lajf_budget_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/life_data.json');
    final data = LifeData(file: file);
    await data.load();

    expect(data.balanceThrough(DateTime(2026, 9)), 0);
    data.money.addAll([
      MoneyEntry(
        id: '1',
        name: 'Savings',
        cents: 10000,
        at: DateTime(2026, 9, 3),
        isIncome: true,
      ),
      MoneyEntry(
        id: '2',
        name: 'Food',
        cents: 3000,
        at: DateTime(2026, 9, 4),
        isIncome: false,
        categoryId: 'food',
      ),
      MoneyEntry(
        id: '3',
        name: 'Rent',
        cents: 9000,
        at: DateTime(2026, 10, 1),
        isIncome: false,
        categoryId: 'bills',
      ),
    ]);
    await data.persist();

    expect(data.balanceThrough(DateTime(2026, 9)), 7000);
    expect(data.balanceThrough(DateTime(2026, 10)), -2000);
    expect(data.addedInMonth(DateTime(2026, 10)), 0);
    final reloaded = LifeData(file: file);
    await reloaded.load();
    expect(reloaded.balanceThrough(DateTime(2026, 10)), -2000);
  });

  test('monthly expense is created once on its due day', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lajf_recurring_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final data = LifeData(file: File('${directory.path}/life_data.json'));
    await data.load();
    data.recurringExpenses.add(
      RecurringExpense(
        id: 'insurance',
        name: 'Insurance',
        cents: 1200,
        categoryId: 'bills',
        day: 31,
        startMonth: '2026-07',
      ),
    );

    await data.generateRecurringExpenses(DateTime(2026, 9, 13));
    expect(
      data.money.length,
      2,
    ); // July 31, August 31. September 30 has not arrived.
    await data.generateRecurringExpenses(DateTime(2026, 9, 13));
    expect(data.money.length, 2);
    await data.generateRecurringExpenses(DateTime(2026, 9, 30));
    expect(data.money.length, 3);
    expect(data.money.last.at, DateTime(2026, 9, 30));
  });

  test('postponed repeating task keeps original day in history', () async {
    final directory = await Directory.systemTemp.createTemp('lajf_tasks_test_');
    addTearDown(() => directory.delete(recursive: true));
    final data = LifeData(file: File('${directory.path}/life_data.json'));
    await data.load();
    data.tasks.add(
      LifeTask(
        id: 'study',
        title: 'Study',
        at: DateTime(2026, 9, 14, 18),
        kind: TaskKind.planner,
        repeat: TaskRepeat.weekly,
        reminderMinutes: [15, 60],
      ),
    );

    final monday = data
        .occurrences(TaskKind.planner, DateTime(2026, 9, 14))
        .single;
    await data.postpone(monday, DateTime(2026, 9, 16));
    expect(data.occurrences(TaskKind.planner, DateTime(2026, 9, 14)), isEmpty);
    expect(
      data
          .occurrences(
            TaskKind.planner,
            DateTime(2026, 9, 14),
            includeHistory: true,
          )
          .single
          .progress!
          .postponedTo,
      DateTime(2026, 9, 16),
    );
    expect(
      data.occurrences(TaskKind.planner, DateTime(2026, 9, 16)),
      hasLength(1),
    );
    expect(
      data.occurrences(TaskKind.planner, DateTime(2026, 9, 21)),
      hasLength(1),
    );
    await data.setCompleted(
      data.occurrences(TaskKind.planner, DateTime(2026, 9, 16)).single,
    );
    expect(
      data
          .occurrences(TaskKind.planner, DateTime(2026, 9, 16))
          .single
          .completed,
      isTrue,
    );
  });

  test('comments persist and removed recurring charge stays removed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lajf_comments_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/life_data.json');
    final data = LifeData(file: file);
    await data.load();
    data.tasks.add(
      LifeTask(
        id: 'task',
        title: 'Study',
        at: DateTime(2026, 9, 13),
        kind: TaskKind.university,
        repeat: TaskRepeat.none,
        reminderMinutes: [],
        comment: 'Bring notes',
      ),
    );
    data.gym['2026-09-13'] = GymDay('push', true, comment: 'Bench 60 kg');
    data.categories.add(
      ExpenseCategory(
        'books',
        'Books',
        0xFF87B7FF,
        comment: 'Course materials',
      ),
    );
    data.recurringExpenses.add(
      RecurringExpense(
        id: 'subscription',
        name: 'Subscription',
        cents: 500,
        categoryId: 'bills',
        day: 5,
        startMonth: '2026-09',
        comment: 'Student plan',
      ),
    );
    await data.generateRecurringExpenses(DateTime(2026, 9, 13));
    final charge = data.money.single;
    expect(charge.comment, 'Student plan');
    data.skippedRecurringIds.add(charge.recurringId!);
    data.money.remove(charge);
    await data.persist();

    final reloaded = LifeData(file: file);
    await reloaded.load();
    await reloaded.generateRecurringExpenses(DateTime(2026, 9, 13));
    // load() also generates charges due in the current month. Only the
    // explicitly removed occurrence must stay absent as calendar time advances.
    expect(
      reloaded.money.where((entry) => entry.recurringId == charge.recurringId),
      isEmpty,
    );
    expect(reloaded.tasks.single.comment, 'Bring notes');
    expect(reloaded.gym['2026-09-13']?.comment, 'Bench 60 kg');
    expect(reloaded.category('books').comment, 'Course materials');
  });

  test('repeating task stops on its selected end date', () async {
    final directory = await Directory.systemTemp.createTemp('lajf_task_end_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/life_data.json');
    final data = LifeData(file: file);
    await data.load();
    data.tasks.add(
      LifeTask(
        id: 'daily',
        title: 'Daily workout',
        at: DateTime(2026, 9, 14, 18),
        kind: TaskKind.planner,
        repeat: TaskRepeat.daily,
        repeatUntil: DateTime(2026, 9, 23),
        reminderMinutes: [15],
      ),
    );
    await data.persist();
    final reloaded = LifeData(file: file);
    await reloaded.load();
    expect(
      reloaded.occurrences(TaskKind.planner, DateTime(2026, 9, 23)),
      hasLength(1),
    );
    expect(
      reloaded.occurrences(TaskKind.planner, DateTime(2026, 9, 24)),
      isEmpty,
    );
    reloaded.tasks.removeWhere((task) => task.id == 'daily');
    await reloaded.persist();
    final cleared = LifeData(file: file);
    await cleared.load();
    expect(cleared.tasks, isEmpty);
  });
}
