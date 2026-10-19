import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lajf_app/groceries.dart';
import 'package:lajf_app/life_data.dart';
import 'package:lajf_app/main.dart';

void main() {
  testWidgets('budget, planner and university fit a phone-sized view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = LifeData()..ready = true;
    await tester.pumpWidget(
      LajfApp(data: data, groceryStore: _MemoryGroceryStore()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();
    expect(find.text('AVAILABLE AT MONTH END'), findsOneWidget);
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    expect(find.text('Gym planner'), findsOneWidget);
    await tester.tap(find.text('Uni'));
    await tester.pumpAndSettle();
    expect(find.text('Today’s reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a grocery from the Groceries tab', (tester) async {
    final store = _MemoryGroceryStore();
    final data = LifeData()..ready = true;

    await tester.pumpWidget(LajfApp(groceryStore: store, data: data));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('Fridge'), findsOneWidget);
    expect(find.text('Freezer'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await tester.tap(find.byTooltip('Add grocery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Milk');
    expect(find.text('Purchased on'), findsOneWidget);
    await tester.ensureVisible(find.text('Save item'));
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);

    final saved = store.items;
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Milk');
    expect(saved.single.category, GroceryCategory.fridge);
    final now = DateTime.now();
    expect(saved.single.purchasedOn.year, now.year);
    expect(saved.single.purchasedOn.month, now.month);
    expect(saved.single.purchasedOn.day, now.day);
  });

  testWidgets('food expense offers a prefilled grocery entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = _MemoryLifeData()..ready = true;
    final store = _MemoryGroceryStore();
    await tester.pumpWidget(LajfApp(data: data, groceryStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Apples');
    await tester.enterText(find.byType(TextField).at(1), '3.50');
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Groceries?'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Add grocery'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Apples'), findsOneWidget);
    await tester.ensureVisible(find.text('Save item'));
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(store.items.single.name, 'Apples');
    expect(data.money.single.name, 'Apples');
  });

  testWidgets('five quick budget taps show the password prompt', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('lajf_app/secure_screen');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final data = LifeData()..ready = true;
    await tester.pumpWidget(
      LajfApp(data: data, groceryStore: _MemoryGroceryStore()),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Budget').last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Set vault password'), findsOneWidget);
  });

  testWidgets(
    'shopping item opens a named Food expense and clears after save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _MemoryGroceryStore();
      final data = _MemoryLifeData()..ready = true;
      await tester.pumpWidget(LajfApp(data: data, groceryStore: store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      expect(find.text('To buy'), findsOneWidget);
      await tester.tap(find.byTooltip('Shopping list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add item').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Apples');
      await tester.enterText(find.byType(TextField).at(2), '2 bags');
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(store.shoppingItems.single.name, 'Apples');

      await tester.tap(find.text('Bought'));
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Apples'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '2.50');
      await tester.ensureVisible(find.text('Save expense'));
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(find.text('Add to Groceries?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(store.shoppingItems, isEmpty);
      expect(data.money.single.categoryId, 'food');
    },
  );

  testWidgets('cancelling the Food expense keeps the shopping item', (
    tester,
  ) async {
    final store = _MemoryGroceryStore()
      ..shoppingItems = [
        const ShoppingItem(id: 'milk', name: 'Milk', quantity: '2 cartons'),
      ];
    final data = _MemoryLifeData()..ready = true;
    await tester.pumpWidget(LajfApp(data: data, groceryStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shopping list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bought'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(store.shoppingItems.single.name, 'Milk');
    expect(data.money, isEmpty);
  });

  testWidgets('remove all repeats keeps one-time planner tasks', (
    tester,
  ) async {
    final data = _MemoryLifeData()..ready = true;
    final today = DateTime.now();
    data.tasks.addAll([
      LifeTask(
        id: 'daily',
        title: 'Daily task',
        at: today,
        kind: TaskKind.planner,
        repeat: TaskRepeat.daily,
        reminderMinutes: [],
      ),
      LifeTask(
        id: 'once',
        title: 'One-time task',
        at: today,
        kind: TaskKind.planner,
        repeat: TaskRepeat.none,
        reminderMinutes: [],
      ),
    ]);
    await tester.pumpWidget(
      LajfApp(data: data, groceryStore: _MemoryGroceryStore()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Manage repeating tasks'), 300);
    await tester.tap(find.text('Manage repeating tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Repeating tasks'), findsOneWidget);
    await tester.tap(find.text('Remove all repeating items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove all').last);
    await tester.pumpAndSettle();
    expect(data.tasks.map((task) => task.id), ['once']);
  });
}

class _MemoryGroceryStore extends GroceryStore {
  List<GroceryItem> items = [];
  List<ShoppingItem> shoppingItems = [];

  @override
  Future<List<GroceryItem>> load() async => items;

  @override
  Future<void> save(List<GroceryItem> updated) async {
    items = updated;
  }

  @override
  Future<List<ShoppingItem>> loadShoppingList() async => shoppingItems;

  @override
  Future<void> saveShoppingList(List<ShoppingItem> updated) async {
    shoppingItems = updated;
  }
}

class _MemoryLifeData extends LifeData {
  @override
  Future<void> persist() async => notifyListeners();
}
