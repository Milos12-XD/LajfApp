import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lajf_app/life_data.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.data, this.onFoodExpenseSaved});
  final LifeData data;
  final Future<void> Function(MoneyEntry)? onFoodExpenseSaved;

  @override
  State<BudgetPage> createState() => BudgetPageState();
}

class BudgetPageState extends State<BudgetPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _yearView = false;

  Future<MoneyEntry?> showEntryEditor({
    bool income = false,
    String? initialName,
    String? initialCategoryId,
  }) async {
    final entry = await showModalBottomSheet<MoneyEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => MoneyEditor(
        data: widget.data,
        income: income,
        initialName: initialName,
        initialCategoryId: initialCategoryId,
      ),
    );
    if (entry == null || !mounted) return null;
    widget.data.money.add(entry);
    if (!await _save()) {
      widget.data.money.remove(entry);
      return null;
    }
    if (!entry.isIncome &&
        widget.data.category(entry.categoryId).name.toLowerCase() == 'food') {
      await widget.onFoodExpenseSaved?.call(entry);
    }
    return entry;
  }

  Future<void> _removeEntry(MoneyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove transaction?'),
        content: Text('Remove ${entry.name} from your budget?'),
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
    widget.data.money.removeWhere((item) => item.id == entry.id);
    if (entry.recurringId != null) {
      widget.data.skippedRecurringIds.add(entry.recurringId!);
    }
    await _save();
  }

  Future<bool> _save() async {
    try {
      await widget.data.persist();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save budget changes.')),
        );
      }
      return false;
    }
  }

  Future<void> _newRecurring() async {
    final plan = await showModalBottomSheet<RecurringExpense>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => RecurringEditor(data: widget.data),
    );
    if (plan == null) return;
    widget.data.recurringExpenses.add(plan);
    await _save();
    await widget.data.generateRecurringExpenses();
  }

  Future<void> _showRecurring() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Monthly expenses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text('Added once on the chosen day of each month.'),
                const SizedBox(height: 14),
                if (widget.data.recurringExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('No recurring expenses yet.'),
                  ),
                for (final plan in widget.data.recurringExpenses)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(plan.name),
                    subtitle: Text(
                      '${euro(plan.cents)} · day ${plan.day} · ${widget.data.category(plan.categoryId).name}${plan.comment.isEmpty ? '' : '\n${plan.comment}'}',
                    ),
                    value: plan.active,
                    onChanged: (active) async {
                      final index = widget.data.recurringExpenses.indexOf(plan);
                      widget.data.recurringExpenses[index] = plan.copyWith(
                        active: active,
                      );
                      refresh(() {});
                      await _save();
                      if (active) await widget.data.generateRecurringExpenses();
                    },
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _newRecurring();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add monthly expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.data,
      builder: (context, _) {
        if (!widget.data.ready) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.data.loadError != null) {
          return Center(child: Text(widget.data.loadError!));
        }
        final monthEntries =
            widget.data.money
                .where(
                  (entry) =>
                      entry.at.year == _month.year &&
                      entry.at.month == _month.month,
                )
                .toList()
              ..sort((a, b) => b.at.compareTo(a.at));
        final spent = widget.data.spentInMonth(_month);
        final added = widget.data.addedInMonth(_month);
        final carried = widget.data.balanceThrough(
          DateTime(_month.year, _month.month - 1),
        );
        final balance = widget.data.balanceThrough(_month);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          children: [
            Text('Budget', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Your money, with a clear view.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Month')),
                ButtonSegment(value: true, label: Text('Year')),
              ],
              selected: {_yearView},
              onSelectionChanged: (value) =>
                  setState(() => _yearView = value.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(
                      _month.year,
                      _month.month + (_yearView ? -12 : -1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _yearView
                        ? '${_month.year}'
                        : '${_monthName(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(
                      _month.year,
                      _month.month + (_yearView ? 12 : 1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_yearView)
              _YearContent(data: widget.data, year: _month.year)
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF193629), Color(0xFF15251F)],
                  ),
                  border: Border.all(color: const Color(0xFF315A45)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE AT MONTH END',
                      style: TextStyle(
                        color: Color(0xFFA9C8B7),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      euro(balance),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Carried ${euro(carried)}  +  Added ${euro(added)}  −  Spent ${euro(spent)}',
                      style: const TextStyle(
                        color: Color(0xFFA9C8B7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showEntryEditor(),
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showEntryEditor(income: true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add money'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showRecurring,
                icon: const Icon(Icons.repeat_rounded),
                label: const Text('Monthly expenses'),
              ),
              const SizedBox(height: 24),
              Text(
                'Spending by category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _SpendingPie(entries: monthEntries, data: widget.data),
              const SizedBox(height: 24),
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (monthEntries.isEmpty)
                const _EmptyBudget()
              else
                for (final entry in monthEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            entry.isIncome
                                ? 0xFF214B34
                                : widget.data.category(entry.categoryId).color,
                          ).withValues(alpha: 0.22),
                          child: Icon(
                            entry.isIncome
                                ? Icons.add_rounded
                                : Icons.shopping_bag_outlined,
                            color: entry.isIncome
                                ? const Color(0xFF9EF0C0)
                                : Color(
                                    widget.data
                                        .category(entry.categoryId)
                                        .color,
                                  ),
                          ),
                        ),
                        title: Text(entry.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dateLabel(entry.at)} · ${timeLabel(entry.at)}${entry.isIncome ? '' : ' · ${widget.data.category(entry.categoryId).name}'}',
                            ),
                            if (entry.comment.isNotEmpty)
                              Text(
                                entry.comment,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${entry.isIncome ? '+' : '−'}${euro(entry.cents)}',
                              style: TextStyle(
                                color: entry.isIncome
                                    ? const Color(0xFF9EF0C0)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Transaction options',
                              onSelected: (_) => _removeEntry(entry),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        );
      },
    );
  }
}

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

class _EmptyBudget extends StatelessWidget {
  const _EmptyBudget();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(22),
      child: Text(
        'No transactions yet. Add money or record an expense to start.',
      ),
    ),
  );
}

class _YearContent extends StatelessWidget {
  const _YearContent({required this.data, required this.year});
  final LifeData data;
  final int year;

  @override
  Widget build(BuildContext context) {
    final spent = data.spentInYear(year);
    final maximum = List.generate(
      12,
      (index) => data.spentInMonth(DateTime(year, index + 1)),
    ).fold<int>(0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPENT THIS YEAR',
                  style: TextStyle(color: Color(0xFFB8BECC), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  euro(spent),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Monthly spending', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (var month = 1; month <= 12; month++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(_monthName(month).substring(0, 3)),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: maximum == 0
                        ? 0
                        : data.spentInMonth(DateTime(year, month)) / maximum,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 82,
                  child: Text(
                    euro(data.spentInMonth(DateTime(year, month))),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpendingPie extends StatelessWidget {
  const _SpendingPie({required this.entries, required this.data});
  final List<MoneyEntry> entries;
  final LifeData data;

  @override
  Widget build(BuildContext context) {
    final groups = <String, int>{};
    for (final entry in entries.where((entry) => !entry.isIncome)) {
      final key = entry.categoryId ?? 'other';
      groups[key] = (groups[key] ?? 0) + entry.cents;
    }
    if (groups.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('Spending chart appears after your first expense.'),
        ),
      );
    }
    final segments = groups.entries
        .map(
          (group) =>
              _PieSlice(group.value, Color(data.category(group.key).color)),
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(painter: _PiePainter(segments)),
            ),
            const SizedBox(height: 18),
            for (final group in groups.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(data.category(group.key).color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data.category(group.key).name)),
                    Text(euro(group.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PieSlice {
  _PieSlice(this.value, this.color);
  final int value;
  final Color color;
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices);
  final List<_PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    if (total == 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.value / total;
      canvas.drawArc(
        rect.deflate(8),
        start,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30,
      );
      start += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      52,
      Paint()..color = const Color(0xFF171B25),
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class MoneyEditor extends StatefulWidget {
  const MoneyEditor({
    super.key,
    required this.data,
    required this.income,
    this.initialName,
    this.initialCategoryId,
  });
  final LifeData data;
  final bool income;
  final String? initialName;
  final String? initialCategoryId;

  @override
  State<MoneyEditor> createState() => _MoneyEditorState();
}

class _MoneyEditorState extends State<MoneyEditor> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  final _amount = TextEditingController();
  final _comment = TextEditingController();
  DateTime _at = DateTime.now();
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId ?? widget.data.categories.first.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final result = await showDialog<ExpenseCategory>(
      context: context,
      builder: (context) => const _CategoryDialog(),
    );
    if (result == null) return;
    widget.data.categories.add(result);
    await widget.data.persist();
    if (mounted) setState(() => _categoryId = result.id);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(
        () => _at = DateTime(
          date.year,
          date.month,
          date.day,
          _at.hour,
          _at.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time != null) {
      setState(
        () => _at = DateTime(
          _at.year,
          _at.month,
          _at.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _submit() {
    final cents = parseEuro(_amount.text);
    if (_name.text.trim().isEmpty || cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and a valid amount.')),
      );
      return;
    }
    Navigator.pop(
      context,
      MoneyEntry(
        id: newId(),
        name: _name.text.trim(),
        cents: cents,
        at: _at,
        isIncome: widget.income,
        categoryId: widget.income ? null : _categoryId,
        comment: _comment.text.trim(),
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
              widget.income ? 'Add money' : 'Add expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.income ? 'Source' : 'Expense name',
                hintText: widget.income ? 'e.g. Paycheck' : 'e.g. Groceries',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '€ ',
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
            if (!widget.income) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in widget.data.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(category.color),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              if (widget.data.category(_categoryId).comment.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.data.category(_categoryId).comment,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New category'),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(dateLabel(_at)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(timeLabel(_at)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.income ? 'Add money' : 'Save expense'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _name = TextEditingController();
  final _comment = TextEditingController();
  int _color = 0xFF8FE3B0;
  static const colors = [
    0xFF8FE3B0,
    0xFF87B7FF,
    0xFFFFB876,
    0xFFE59CD6,
    0xFFB5A6FF,
    0xFFFF8989,
    0xFFFFD66D,
    0xFF87D9DC,
  ];

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New category'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: false,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Comment (optional)'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in colors)
                InkWell(
                  onTap: () => setState(() => _color = color),
                  child: CircleAvatar(
                    backgroundColor: Color(color),
                    radius: 18,
                    child: _color == color
                        ? const Icon(Icons.check_rounded, color: Colors.black)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            ExpenseCategory(
              newId(),
              _name.text.trim(),
              _color,
              comment: _comment.text.trim(),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class RecurringEditor extends StatefulWidget {
  const RecurringEditor({super.key, required this.data});
  final LifeData data;
  @override
  State<RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<RecurringEditor> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _comment = TextEditingController();
  late String _categoryId = widget.data.categories.first.id;
  int _day = DateTime.now().day;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _comment.dispose();
    super.dispose();
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
              'Monthly expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: false,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Insurance',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '€ ',
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
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in widget.data.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _categoryId = value);
              },
            ),
            if (widget.data.category(_categoryId).comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.data.category(_categoryId).comment,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day of month'),
              items: [
                for (var day = 1; day <= 31; day++)
                  DropdownMenuItem(value: day, child: Text('$day')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _day = value);
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'For shorter months, this expense lands on the last day.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final cents = parseEuro(_amount.text);
                if (_name.text.trim().isEmpty || cents == null || cents <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a name and a valid amount.'),
                    ),
                  );
                  return;
                }
                final now = DateTime.now();
                Navigator.pop(
                  context,
                  RecurringExpense(
                    id: newId(),
                    name: _name.text.trim(),
                    cents: cents,
                    categoryId: _categoryId,
                    day: _day,
                    startMonth:
                        '${now.year}-${now.month.toString().padLeft(2, '0')}',
                    comment: _comment.text.trim(),
                  ),
                );
              },
              child: const Text('Save monthly expense'),
            ),
          ],
        ),
      ),
    ),
  );
}
