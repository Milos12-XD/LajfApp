import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum GroceryCategory {
  fridge('Fridge', Icons.kitchen_rounded),
  freezer('Freezer', Icons.ac_unit_rounded),
  snacks('Snacks', Icons.cookie_rounded),
  drinks('Drinks', Icons.local_drink_rounded),
  other('Other', Icons.inventory_2_rounded);

  const GroceryCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.purchasedOn,
    this.expiresOn,
    this.quantity = '',
    this.comment = '',
  });

  final String id;
  final String name;
  final GroceryCategory category;
  final DateTime purchasedOn;
  final DateTime? expiresOn;
  final String quantity;
  final String comment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'purchasedOn': _dateKey(purchasedOn),
    'expiresOn': expiresOn == null ? null : _dateKey(expiresOn!),
    'quantity': quantity,
    'comment': comment,
  };

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: GroceryCategory.values.firstWhere(
        (category) => category.name == json['category'],
        orElse: () => GroceryCategory.other,
      ),
      purchasedOn: DateTime.parse(json['purchasedOn'] as String),
      expiresOn: json['expiresOn'] == null
          ? null
          : DateTime.parse(json['expiresOn'] as String),
      quantity: json['quantity'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
    );
  }
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.description = '',
    this.quantity = '',
  });

  final String id;
  final String name;
  final String description;
  final String quantity;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'quantity': quantity,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    quantity: json['quantity'] as String? ?? '',
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class GroceryStore {
  GroceryStore({File? file}) : _providedFile = file;

  final File? _providedFile;

  Future<File> _file() async {
    if (_providedFile != null) return _providedFile;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}groceries.json');
  }

  Future<File> _shoppingFile() async {
    final groceries = await _file();
    return File(
      '${groceries.parent.path}${Platform.pathSeparator}shopping_list.json',
    );
  }

  Future<List<GroceryItem>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List<dynamic>;
    return data
        .map((entry) => GroceryItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<GroceryItem> items) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  Future<List<ShoppingItem>> loadShoppingList() async {
    final file = await _shoppingFile();
    if (!await file.exists()) return [];
    return (jsonDecode(await file.readAsString()) as List<dynamic>)
        .map((entry) => ShoppingItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveShoppingList(List<ShoppingItem> items) async {
    final file = await _shoppingFile();
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}

class GroceriesPage extends StatefulWidget {
  const GroceriesPage({super.key, this.store, this.onBuyShoppingItem});

  final GroceryStore? store;
  final Future<bool> Function(ShoppingItem)? onBuyShoppingItem;

  @override
  State<GroceriesPage> createState() => GroceriesPageState();
}

class GroceriesPageState extends State<GroceriesPage> {
  late final GroceryStore _store = widget.store ?? GroceryStore();
  List<GroceryItem> _items = [];
  List<ShoppingItem> _shoppingItems = [];
  GroceryCategory? _selectedCategory;
  bool _loading = true;
  bool _saving = false;
  bool _shoppingSaving = false;
  String? _loadError;
  String? _shoppingError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _store.load();
      List<ShoppingItem> shoppingItems = [];
      String? shoppingError;
      try {
        shoppingItems = await _store.loadShoppingList();
      } catch (_) {
        shoppingError = 'Could not load your shopping list.';
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _shoppingItems = shoppingItems;
        _shoppingError = shoppingError;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Could not load groceries. Your saved data was not changed.';
      });
    }
  }

  Future<bool> _commitShopping(List<ShoppingItem> updated) async {
    if (_shoppingSaving || _shoppingError != null) return false;
    setState(() => _shoppingSaving = true);
    try {
      await _store.saveShoppingList(updated);
      if (!mounted) return false;
      setState(() => _shoppingItems = updated);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save shopping list.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _shoppingSaving = false);
    }
  }

  Future<void> showShoppingList() async {
    if (_loading || _shoppingError != null) return;
    final bought = await showModalBottomSheet<ShoppingItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: StatefulBuilder(
          builder: (context, refresh) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Shopping list',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_shoppingItems.length} items to buy',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _shoppingItems.isEmpty
                        ? const Center(child: Text('Nothing to buy yet.'))
                        : ListView.builder(
                            itemCount: _shoppingItems.length,
                            itemBuilder: (context, index) {
                              final item = _shoppingItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        if (item.quantity.isNotEmpty)
                                          Text('Quantity: ${item.quantity}'),
                                        if (item.description.isNotEmpty)
                                          Text(
                                            item.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.tonalIcon(
                                            onPressed: () => Navigator.pop(
                                              sheetContext,
                                              item,
                                            ),
                                            icon: const Icon(
                                              Icons.check_rounded,
                                            ),
                                            label: const Text('Bought'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _shoppingSaving
                        ? null
                        : () async {
                            final item =
                                await showModalBottomSheet<ShoppingItem>(
                                  context: sheetContext,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  backgroundColor: const Color(0xFF171B25),
                                  builder: (context) =>
                                      const _ShoppingItemEditor(),
                                );
                            if (item == null || !mounted) return;
                            final saved = await _commitShopping([
                              ..._shoppingItems,
                              item,
                            ]);
                            if (saved && sheetContext.mounted) refresh(() {});
                          },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add item'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (bought == null || !mounted) return;
    final recorded = await widget.onBuyShoppingItem?.call(bought) ?? false;
    if (recorded && mounted) {
      await _commitShopping(
        _shoppingItems.where((item) => item.id != bought.id).toList(),
      );
    }
  }

  Future<void> _commit(List<GroceryItem> updated) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.save(updated);
      if (!mounted) return;
      setState(() => _items = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> showItemEditor([
    GroceryItem? item,
    String? initialName,
    DateTime? initialPurchasedOn,
  ]) async {
    if (_loading || _saving || _loadError != null) return;
    final result = await showModalBottomSheet<GroceryItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => GroceryEditor(
        item: item,
        initialName: initialName,
        initialPurchasedOn: initialPurchasedOn,
        initialCategory: _selectedCategory ?? GroceryCategory.fridge,
      ),
    );
    if (result == null || !mounted) return;
    final updated = [..._items];
    final index = updated.indexWhere((entry) => entry.id == result.id);
    if (index == -1) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    await _commit(updated);
  }

  Future<void> _delete(GroceryItem item) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove ${item.name} from your groceries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _commit(_items.where((entry) => entry.id != item.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final attention = _items.where((item) {
      final expiry = item.expiresOn;
      return expiry != null && _daysBetween(today, expiry) <= 3;
    }).length;
    final visible =
        _items
            .where(
              (item) =>
                  _selectedCategory == null ||
                  item.category == _selectedCategory,
            )
            .toList()
          ..sort((a, b) {
            if (a.expiresOn == null && b.expiresOn != null) return 1;
            if (a.expiresOn != null && b.expiresOn == null) return -1;
            if (a.expiresOn != null && b.expiresOn != null) {
              final expiryOrder = a.expiresOn!.compareTo(b.expiresOn!);
              if (expiryOrder != 0) return expiryOrder;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          children: [
            Text(
              'Groceries',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Know what you have. Refill what you need.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    value: '${_items.length}',
                    label: 'Items at home',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    value: '$attention',
                    label: 'Need attention',
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    value: '${_shoppingItems.length}',
                    label: 'To buy',
                    icon: Icons.shopping_cart_outlined,
                  ),
                ),
              ],
            ),
            if (_shoppingError != null) ...[
              const SizedBox(height: 8),
              Text(
                _shoppingError!,
                style: const TextStyle(color: Color(0xFFFFB58C)),
              ),
            ],
            const SizedBox(height: 22),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip(null, 'All', Icons.apps_rounded),
                  for (final category in GroceryCategory.values)
                    _categoryChip(category, category.label, category.icon),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Column(
                children: [
                  Text(_loadError!),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else if (visible.isEmpty)
              _EmptyGroceries(
                onAdd: () => showItemEditor(),
                category: _selectedCategory,
              )
            else ...[
              Text(
                _selectedCategory?.label ?? 'All items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final item in visible) ...[
                _GroceryTile(
                  item: item,
                  onTap: () => showItemEditor(item),
                  onDelete: () => _delete(item),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
        Positioned(
          left: 20,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'shopping-list',
            onPressed: showShoppingList,
            tooltip: 'Shopping list',
            child: const Icon(Icons.shopping_cart_rounded),
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(GroceryCategory? category, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: _selectedCategory == category,
        onSelected: (_) => setState(() => _selectedCategory = category),
        avatar: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 124,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyGroceries extends StatelessWidget {
  const _EmptyGroceries({required this.onAdd, required this.category});

  final VoidCallback onAdd;
  final GroceryCategory? category;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 44,
            color: Color(0xFF9EF0C0),
          ),
          const SizedBox(height: 14),
          Text(
            category == null
                ? 'Your shelves are empty'
                : 'Nothing in ${category!.label.toLowerCase()} yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Add what you have at home to keep track of it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ],
      ),
    ),
  );
}

class _GroceryTile extends StatelessWidget {
  const _GroceryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final GroceryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final daysLeft = item.expiresOn == null
        ? null
        : _daysBetween(today, item.expiresOn!);
    final status = daysLeft == null
        ? 'No expiry'
        : daysLeft < 0
        ? 'Expired'
        : daysLeft == 0
        ? 'Expires today'
        : daysLeft <= 3
        ? 'Expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'
        : 'Expires ${_displayDate(item.expiresOn!)}';
    final alert = daysLeft != null && daysLeft <= 3;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFF26362F),
                child: Icon(
                  item.category.icon,
                  color: const Color(0xFF9EF0C0),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category.label}${item.quantity.isEmpty ? '' : ' · ${item.quantity}'} · Bought ${_displayDate(item.purchasedOn)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: alert
                            ? const Color(0xFFFFB58C)
                            : const Color(0xFF9EF0C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Item options',
                onSelected: (value) => value == 'edit' ? onTap() : onDelete(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShoppingItemEditor extends StatefulWidget {
  const _ShoppingItemEditor();

  @override
  State<_ShoppingItemEditor> createState() => _ShoppingItemEditorState();
}

class _ShoppingItemEditorState extends State<_ShoppingItemEditor> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an item name.')));
      return;
    }
    Navigator.pop(
      context,
      ShoppingItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        description: _description.text.trim(),
        quantity: _quantity.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to shopping list',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Quantity (optional)',
                hintText: 'e.g. 2 packs',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('Save item')),
          ],
        ),
      ),
    ),
  );
}

class GroceryEditor extends StatefulWidget {
  const GroceryEditor({
    super.key,
    this.item,
    this.initialName,
    this.initialPurchasedOn,
    required this.initialCategory,
  });

  final GroceryItem? item;
  final String? initialName;
  final DateTime? initialPurchasedOn;
  final GroceryCategory initialCategory;

  @override
  State<GroceryEditor> createState() => _GroceryEditorState();
}

class _GroceryEditorState extends State<GroceryEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item?.name ?? widget.initialName ?? '',
  );
  late final TextEditingController _quantity = TextEditingController(
    text: widget.item?.quantity ?? '',
  );
  late final TextEditingController _comment = TextEditingController(
    text: widget.item?.comment ?? '',
  );
  late GroceryCategory _category =
      widget.item?.category ?? widget.initialCategory;
  late DateTime _purchasedOn =
      widget.item?.purchasedOn ??
      widget.initialPurchasedOn ??
      _day(DateTime.now());
  DateTime? _expiresOn;

  @override
  void initState() {
    super.initState();
    _expiresOn = widget.item?.expiresOn;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickPurchasedOn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedOn,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _purchasedOn = picked;
      if (_expiresOn != null && _expiresOn!.isBefore(picked)) _expiresOn = null;
    });
  }

  Future<void> _pickExpiresOn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? _purchasedOn,
      firstDate: _purchasedOn,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiresOn = picked);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an item name.')));
      return;
    }
    Navigator.pop(
      context,
      GroceryItem(
        id: widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        category: _category,
        purchasedOn: _purchasedOn,
        expiresOn: _expiresOn,
        quantity: _quantity.text.trim(),
        comment: _comment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null ? 'Add grocery' : 'Edit grocery',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                autofocus: false,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. Milk',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                decoration: const InputDecoration(
                  labelText: 'Quantity (optional)',
                  hintText: 'e.g. 2 cartons',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GroceryCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in GroceryCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Purchased on',
                value: _displayDate(_purchasedOn),
                onTap: _pickPurchasedOn,
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Expiry date',
                value: _expiresOn == null
                    ? 'No expiry date'
                    : _displayDate(_expiresOn!),
                onTap: _pickExpiresOn,
                onClear: _expiresOn == null
                    ? null
                    : () => setState(() => _expiresOn = null),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    widget.item == null ? 'Save item' : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF202531),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Color(0xFF9EF0C0)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(value),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                tooltip: 'Clear expiry date',
                icon: const Icon(Icons.close_rounded),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
