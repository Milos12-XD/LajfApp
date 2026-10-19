import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lajf_app/groceries.dart';

void main() {
  test('grocery dates and category survive local storage', () async {
    final directory = await Directory.systemTemp.createTemp('lajf_store_test_');
    addTearDown(() => directory.delete(recursive: true));
    final store = GroceryStore(file: File('${directory.path}/groceries.json'));
    final item = GroceryItem(
      id: 'milk-1',
      name: 'Milk',
      category: GroceryCategory.fridge,
      quantity: '2 cartons',
      purchasedOn: DateTime(2026, 9, 13),
      expiresOn: DateTime(2026, 9, 20),
      comment: 'For breakfast',
    );

    expect(await store.load(), isEmpty);
    await store.save([item]);
    final loaded = await GroceryStore(
      file: File('${directory.path}/groceries.json'),
    ).load();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Milk');
    expect(loaded.single.category, GroceryCategory.fridge);
    expect(loaded.single.quantity, '2 cartons');
    expect(loaded.single.purchasedOn, DateTime(2026, 9, 13));
    expect(loaded.single.expiresOn, DateTime(2026, 9, 20));
    expect(loaded.single.comment, 'For breakfast');
  });

  test('shopping list is stored separately from groceries at home', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lajf_shopping_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = GroceryStore(file: File('${directory.path}/groceries.json'));
    await store.saveShoppingList(const [
      ShoppingItem(
        id: 'apples',
        name: 'Apples',
        description: 'Green ones',
        quantity: '2 bags',
      ),
    ]);
    expect(await store.load(), isEmpty);
    final reloaded = GroceryStore(
      file: File('${directory.path}/groceries.json'),
    );
    final shopping = await reloaded.loadShoppingList();
    expect(shopping.single.name, 'Apples');
    expect(shopping.single.description, 'Green ones');
    expect(shopping.single.quantity, '2 bags');
  });
}
