import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lajf_app/budget.dart';
import 'package:lajf_app/groceries.dart';
import 'package:lajf_app/life_data.dart';
import 'package:lajf_app/notifications.dart';
import 'package:lajf_app/planner.dart';
import 'package:lajf_app/vault.dart';
import 'package:lajf_app/vault_access.dart';

void main() => runApp(const LajfApp());

class LajfApp extends StatelessWidget {
  const LajfApp({super.key, this.groceryStore, this.data});
  final GroceryStore? groceryStore;
  final LifeData? data;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF171B25);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LajfApp',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1017),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9EF0C0),
          secondary: Color(0xFFB7A7FF),
          surface: surface,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, height: 1.1),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: Color(0xFFB8BECC), height: 1.4),
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
            side: BorderSide(color: Color(0xFF252B38)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF121620),
          indicatorColor: Color(0xFF284536),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      home: AppShell(groceryStore: groceryStore, data: data),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.groceryStore, this.data});
  final GroceryStore? groceryStore;
  final LifeData? data;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _budgetTapTimes = <DateTime>[];
  DateTime? _vaultLockedUntil;
  int _vaultFailures = 0;
  bool _vaultOpening = false;
  final _vaultAccess = VaultAccess();
  int _vaultAccessGeneration = 0;
  static const _secureScreen = MethodChannel('lajf_app/secure_screen');
  late final LifeData _data = widget.data ?? LifeData();
  final _notifications = LifeNotifications();
  final _groceriesKey = GlobalKey<GroceriesPageState>();
  final _budgetKey = GlobalKey<BudgetPageState>();
  final _plannerKey = GlobalKey<TaskPageState>();
  final _uniKey = GlobalKey<TaskPageState>();
  late final List<Widget> _pages = [
    TodayPage(
      data: _data,
      onBudget: () => setState(() => _currentIndex = 1),
      onPlanner: () => setState(() => _currentIndex = 2),
      onUni: () => setState(() => _currentIndex = 3),
      onToggle: (occurrence) => _plannerKey.currentState?.toggle(occurrence),
      onRemove: (occurrence) =>
          _plannerKey.currentState?.removeOrPostpone(occurrence),
    ),
    BudgetPage(key: _budgetKey, data: _data, onFoodExpenseSaved: _offerGrocery),
    TaskPage(
      key: _plannerKey,
      data: _data,
      kind: TaskKind.planner,
      onTasksChanged: _scheduleNotifications,
      onRequestNotifications: _notifications.requestPermission,
    ),
    TaskPage(
      key: _uniKey,
      data: _data,
      kind: TaskKind.university,
      onTasksChanged: _scheduleNotifications,
      onRequestNotifications: _notifications.requestPermission,
    ),
    GroceriesPage(
      key: _groceriesKey,
      store: widget.groceryStore,
      onBuyShoppingItem: _buyShoppingItem,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    if (!_data.ready) await _data.load();
    await _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    try {
      await _notifications.scheduleAll(_data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reminders could not be scheduled. Check notification settings.',
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _vaultAccessGeneration++;
      if (_vaultOpening && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
    if (state == AppLifecycleState.resumed && _data.ready) {
      _data.generateRecurringExpenses();
      _scheduleNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.data == null) _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(index: _currentIndex, children: _pages),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _addCurrent,
      tooltip: _currentIndex == 4 ? 'Add grocery' : 'Quick add',
      child: const Icon(Icons.add_rounded),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
        NavigationDestination(
          icon: Icon(Icons.pie_chart_rounded),
          label: 'Budget',
        ),
        NavigationDestination(
          icon: Icon(Icons.check_circle_rounded),
          label: 'Planner',
        ),
        NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Uni'),
        NavigationDestination(
          icon: Icon(Icons.kitchen_rounded),
          label: 'Groceries',
        ),
      ],
    ),
  );

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index != 1) {
      _budgetTapTimes.clear();
      return;
    }
    final now = DateTime.now();
    _budgetTapTimes.removeWhere(
      (tap) => now.difference(tap) > const Duration(milliseconds: 1500),
    );
    _budgetTapTimes.add(now);
    if (_budgetTapTimes.length >= 5) {
      _budgetTapTimes.clear();
      _openVault();
    }
  }

  Future<void> _offerGrocery(MoneyEntry entry) async {
    if (!mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Groceries?'),
        content: Text('Add ${entry.name} to your food at home?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (add != true || !mounted) return;
    setState(() => _currentIndex = 4);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _groceriesKey.currentState?.showItemEditor(null, entry.name, entry.at);
      }
    });
  }

  Future<bool> _buyShoppingItem(ShoppingItem item) async {
    if (!mounted) return false;
    setState(() => _currentIndex = 0);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    final entry = await _budgetKey.currentState?.showEntryEditor(
      initialName: item.name,
      initialCategoryId: 'food',
    );
    return entry != null;
  }

  Future<void> _openVault() async {
    if (_vaultOpening || !mounted) return;
    final now = DateTime.now();
    if (_vaultLockedUntil?.isAfter(now) == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too many attempts. Try again shortly.')),
      );
      return;
    }
    _vaultOpening = true;
    final generation = _vaultAccessGeneration;
    try {
      await _secureScreen.invokeMethod<void>('setSecure', true);
      if (!mounted) return;
      final setup = await _vaultAccess.requiresSetup();
      if (!mounted || generation != _vaultAccessGeneration) return;
      final password = await showDialog<String>(
        context: context,
        builder: (context) => VaultPasswordDialog(setup: setup),
      );
      if (!mounted ||
          password == null ||
          generation != _vaultAccessGeneration) {
        return;
      }
      final authorized = setup
          ? await _vaultAccess.setUp(password).then((_) => true)
          : await _vaultAccess.verify(password);
      if (!mounted || generation != _vaultAccessGeneration) return;
      if (!authorized) {
        _vaultFailures++;
        if (_vaultFailures >= 3) {
          _vaultLockedUntil = DateTime.now().add(const Duration(seconds: 30));
          _vaultFailures = 0;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incorrect password.')));
        return;
      }
      _vaultFailures = 0;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const VaultPage()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vault unavailable. Existing cards are preserved; '
              'legacy vaults require migration from the original app.',
            ),
          ),
        );
      }
    } finally {
      try {
        await _secureScreen.invokeMethod<void>('setSecure', false);
      } catch (_) {}
      _vaultOpening = false;
    }
  }

  void _addCurrent() {
    switch (_currentIndex) {
      case 0:
        _showQuickAdd();
      case 1:
        _budgetKey.currentState?.showEntryEditor();
      case 2:
        _plannerKey.currentState?.showTaskEditor();
      case 3:
        _uniKey.currentState?.showTaskEditor();
      case 4:
        _groceriesKey.currentState?.showItemEditor();
    }
  }

  void _showQuickAdd() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick add', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _quickTile(
                sheetContext,
                Icons.shopping_bag_rounded,
                'Expense',
                () => _budgetKey.currentState?.showEntryEditor(),
              ),
              _quickTile(
                sheetContext,
                Icons.account_balance_wallet_rounded,
                'Add money',
                () => _budgetKey.currentState?.showEntryEditor(income: true),
              ),
              _quickTile(
                sheetContext,
                Icons.task_alt_rounded,
                'Task',
                () => _plannerKey.currentState?.showTaskEditor(),
              ),
              _quickTile(
                sheetContext,
                Icons.event_rounded,
                'University reminder',
                () => _uniKey.currentState?.showTaskEditor(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickTile(
    BuildContext sheetContext,
    IconData icon,
    String label,
    VoidCallback action,
  ) => ListTile(
    leading: Icon(icon, color: const Color(0xFF9EF0C0)),
    title: Text(label),
    onTap: () {
      Navigator.pop(sheetContext);
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    },
  );
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.data,
    required this.onBudget,
    required this.onPlanner,
    required this.onUni,
    required this.onToggle,
    required this.onRemove,
  });
  final LifeData data;
  final VoidCallback onBudget;
  final VoidCallback onPlanner;
  final VoidCallback onUni;
  final ValueChanged<TaskOccurrence> onToggle;
  final ValueChanged<TaskOccurrence> onRemove;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: data,
    builder: (context, _) {
      if (!data.ready) return const Center(child: CircularProgressIndicator());
      if (data.loadError != null) return Center(child: Text(data.loadError!));
      final now = DateTime.now();
      final today = data.occurrences(TaskKind.planner, now);
      final upcoming = <TaskOccurrence>[];
      for (var day = 0; day < 365 && upcoming.isEmpty; day++) {
        upcoming.addAll(
          data.occurrences(
            TaskKind.university,
            dayOnly(now).add(Duration(days: day)),
          ),
        );
      }
      final weeklyRemaining = data.weeklyRemaining;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Text(
            _longDate(now).toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _greeting(now),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 26),
          InkWell(
            onTap: onBudget,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF193629), Color(0xFF15251F)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF315A45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WEEKLY BUDGET',
                    style: TextStyle(
                      color: Color(0xFFA9C8B7),
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    euro(weeklyRemaining),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'remaining from €70 this week',
                    style: TextStyle(color: Color(0xFFA9C8B7)),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ((7000 - weeklyRemaining) / 7000).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: const Color(0xFF315041),
                      color: const Color(0xFF9EF0C0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Spent ${euro(7000 - weeklyRemaining)} · Monday to Sunday',
                    style: const TextStyle(
                      color: Color(0xFFA9C8B7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _Heading(title: 'Today’s plan', action: 'View all', onTap: onPlanner),
          const SizedBox(height: 12),
          if (today.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No tasks yet. Tap + to plan your day.'),
              ),
            )
          else
            for (final occurrence in today)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: TaskCard(
                  occurrence: occurrence,
                  onToggle: () => onToggle(occurrence),
                  onRemove: () => onRemove(occurrence),
                ),
              ),
          const SizedBox(height: 26),
          _Heading(title: 'Next deadline', action: 'University', onTap: onUni),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              onTap: onUni,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFF29233F),
                      child: Icon(
                        upcoming.isEmpty
                            ? Icons.school_outlined
                            : Icons.event_rounded,
                        color: const Color(0xFFB7A7FF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            upcoming.isEmpty
                                ? 'No upcoming deadlines'
                                : upcoming.first.task.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            upcoming.isEmpty
                                ? 'Tap to add your first reminder'
                                : '${dateLabel(upcoming.first.at)} · ${timeLabel(upcoming.first.at)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF747D90),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning.';
  if (now.hour < 18) return 'Good afternoon.';
  return 'Good evening.';
}

String _longDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}
