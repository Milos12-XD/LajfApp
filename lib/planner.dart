import 'package:flutter/material.dart';
import 'package:lajf_app/life_data.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({
    super.key,
    required this.data,
    required this.kind,
    required this.onTasksChanged,
    required this.onRequestNotifications,
  });
  final LifeData data;
  final TaskKind kind;
  final Future<void> Function() onTasksChanged;
  final Future<bool> Function() onRequestNotifications;

  @override
  State<TaskPage> createState() => TaskPageState();
}

class TaskPageState extends State<TaskPage> {
  bool get _isUni => widget.kind == TaskKind.university;

  Future<void> showTaskEditor() async {
    final task = await showModalBottomSheet<LifeTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => TaskEditor(kind: widget.kind),
    );
    if (task == null || !mounted) return;
    if (task.reminderMinutes.isNotEmpty) {
      final granted = await widget.onRequestNotifications();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off. Enable them in Android settings.',
            ),
          ),
        );
      }
    }
    widget.data.tasks.add(task);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await widget.data.persist();
      await widget.onTasksChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save or schedule reminders. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> toggle(TaskOccurrence occurrence) async {
    await widget.data.setCompleted(occurrence);
    await widget.onTasksChanged();
  }

  Future<void> removeOrPostpone(TaskOccurrence occurrence) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                occurrence.task.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: const Text('Postpone to another day'),
              onTap: () => Navigator.pop(context, 'postpone'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_rounded),
              title: const Text('Remove with an explanation'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            if (occurrence.task.repeat != TaskRepeat.none) ...[
              ListTile(
                leading: const Icon(Icons.event_available_rounded),
                title: const Text('Set repeat end date'),
                onTap: () => Navigator.pop(context, 'end'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: const Text('Remove entire series'),
                onTap: () => Navigator.pop(context, 'series'),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (choice == 'postpone' && mounted) {
      final date = await showDatePicker(
        context: context,
        initialDate: dayOnly(occurrence.at).add(const Duration(days: 1)),
        firstDate: dayOnly(occurrence.at).add(const Duration(days: 1)),
        lastDate: DateTime(2100),
      );
      if (date != null) {
        await widget.data.postpone(occurrence, date);
        await widget.onTasksChanged();
      }
    } else if (choice == 'remove' && mounted) {
      final reason = await _reasonDialog();
      if (reason != null) {
        await widget.data.removeOccurrence(occurrence, reason);
        await widget.onTasksChanged();
      }
    } else if (choice == 'end' && mounted) {
      await _setRepeatEnd(occurrence.task);
    } else if (choice == 'series' && mounted) {
      await _removeSeries(occurrence.task);
    }
  }

  Future<void> _setRepeatEnd(LifeTask task) async {
    final first = dayOnly(task.at);
    final now = dayOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: task.repeatUntil ?? (now.isAfter(first) ? now : first),
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final index = widget.data.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    widget.data.tasks[index] = task.withRepeatUntil(selected);
    await _persist();
  }

  Future<void> _removeSeries(LifeTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove entire series?'),
        content: Text(
          'Remove every occurrence of ${task.title}, including its history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove series'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.data.tasks.removeWhere((item) => item.id == task.id);
    await _persist();
  }

  Future<void> _manageRepeats() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: StatefulBuilder(
          builder: (context, refresh) {
            final repeated = widget.data.tasks
                .where(
                  (task) =>
                      task.kind == widget.kind &&
                      task.repeat != TaskRepeat.none,
                )
                .toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Repeating ${_isUni ? 'reminders' : 'tasks'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: repeated.isEmpty
                          ? const Center(child: Text('No repeating items.'))
                          : ListView(
                              children: [
                                for (final task in repeated)
                                  Card(
                                    child: ListTile(
                                      title: Text(task.title),
                                      subtitle: Text(
                                        '${task.repeat.name} · ${task.repeatUntil == null ? 'No end date' : 'Until ${dateLabel(task.repeatUntil!)}'}',
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Repeat options',
                                        onSelected: (value) async {
                                          if (value == 'end') {
                                            await _setRepeatEnd(task);
                                          } else {
                                            await _removeSeries(task);
                                          }
                                          if (sheetContext.mounted) {
                                            refresh(() {});
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'end',
                                            child: Text('Set end date'),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Remove series'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    if (repeated.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove all repeating items?'),
                              content: const Text(
                                'This also removes their completed history.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove all'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;
                          widget.data.tasks.removeWhere(
                            (task) =>
                                task.kind == widget.kind &&
                                task.repeat != TaskRepeat.none,
                          );
                          await _persist();
                          if (sheetContext.mounted) refresh(() {});
                        },
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text('Remove all repeating items'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String?> _reasonDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Why remove it?'),
          content: TextField(
            controller: controller,
            autofocus: false,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Optional explanation'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                controller.text.trim().isEmpty
                    ? 'Removed'
                    : controller.text.trim(),
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.data,
    builder: (context, _) {
      if (!widget.data.ready) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.data.loadError != null) {
        return Center(child: Text(widget.data.loadError!));
      }
      final today = dayOnly(DateTime.now());
      final todayItems = widget.data.occurrences(widget.kind, today);
      final weekItems = <TaskOccurrence>[];
      for (var i = 1; i <= 7 - today.weekday; i++) {
        weekItems.addAll(
          widget.data.occurrences(widget.kind, today.add(Duration(days: i))),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          Text(
            _isUni ? 'University' : 'Planner',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _isUni
                ? 'Deadlines and reminders in one place.'
                : 'Your day, then the week ahead.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isUni ? 'Today’s reminders' : 'Today’s tasks',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: showTaskEditor,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (todayItems.isEmpty)
            _EmptyTasks(
              label: _isUni ? 'No reminders for today.' : 'No tasks for today.',
            )
          else
            for (final occurrence in todayItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TaskCard(
                  occurrence: occurrence,
                  onToggle: () => toggle(occurrence),
                  onRemove: () => removeOrPostpone(occurrence),
                ),
              ),
          const SizedBox(height: 22),
          Text('This week', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (weekItems.isEmpty)
            const _EmptyTasks(label: 'Nothing else this week.')
          else
            for (final occurrence in weekItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TaskCard(
                  occurrence: occurrence,
                  onToggle: () => toggle(occurrence),
                  onRemove: () => removeOrPostpone(occurrence),
                  showDate: true,
                ),
              ),
          const SizedBox(height: 25),
          if (!_isUni) ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Text('💪')),
                title: const Text('Gym planner'),
                subtitle: const Text('Plan and review your training days'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GymPage(data: widget.data)),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          OutlinedButton.icon(
            onPressed: _manageRepeats,
            icon: const Icon(Icons.repeat_rounded),
            label: Text(
              _isUni ? 'Manage repeating reminders' : 'Manage repeating tasks',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TaskCalendarPage(data: widget.data, kind: widget.kind),
              ),
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Calendar overview'),
          ),
        ],
      );
    },
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Text(label)),
  );
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.occurrence,
    required this.onToggle,
    required this.onRemove,
    this.showDate = false,
  });
  final TaskOccurrence occurrence;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final bool showDate;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: occurrence.completed ? 0.48 : 1,
    child: Card(
      child: Row(
        children: [
          Checkbox(value: occurrence.completed, onChanged: (_) => onToggle()),
          Expanded(
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: occurrence.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${showDate ? '${dateLabel(occurrence.at)} · ' : ''}${timeLabel(occurrence.at)}${occurrence.task.repeat == TaskRepeat.none ? '' : ' · ${occurrence.task.repeat.name}'}${occurrence.task.repeatUntil == null ? '' : ' · until ${dateLabel(occurrence.task.repeatUntil!)}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (occurrence.task.comment.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        occurrence.task.comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove or postpone',
          ),
        ],
      ),
    ),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.kind});
  final TaskKind kind;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _title = TextEditingController();
  final _comment = TextEditingController();
  DateTime _at = DateTime.now().add(const Duration(hours: 1));
  TaskRepeat _repeat = TaskRepeat.none;
  DateTime? _repeatUntil;
  final _selectedOffsets = <int>{};
  static const offsets = [5, 15, 30, 60, 120, 180, 480, 720, 1440, 2160, 2880];

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _at = DateTime(date.year, date.month, date.day, _at.hour, _at.minute);
        if (_repeatUntil != null && _repeatUntil!.isBefore(dayOnly(_at))) {
          _repeatUntil = null;
        }
      });
    }
  }

  Future<void> _pickRepeatUntil() async {
    final start = dayOnly(_at);
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? start,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _repeatUntil = picked);
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
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a title.')));
      return;
    }
    Navigator.pop(
      context,
      LifeTask(
        id: newId(),
        title: _title.text.trim(),
        at: _at,
        kind: widget.kind,
        repeat: _repeat,
        repeatUntil: _repeat == TaskRepeat.none ? null : _repeatUntil,
        reminderMinutes: _selectedOffsets.toList()..sort(),
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
              widget.kind == TaskKind.university ? 'Add reminder' : 'Add task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.kind == TaskKind.university
                    ? 'Reminder name'
                    : 'Task name',
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
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskRepeat>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: const [
                DropdownMenuItem(
                  value: TaskRepeat.none,
                  child: Text('Does not repeat'),
                ),
                DropdownMenuItem(
                  value: TaskRepeat.daily,
                  child: Text('Every day'),
                ),
                DropdownMenuItem(
                  value: TaskRepeat.weekly,
                  child: Text('Every week'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _repeat = value;
                    if (value == TaskRepeat.none) _repeatUntil = null;
                  });
                }
              },
            ),
            if (_repeat != TaskRepeat.none) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickRepeatUntil,
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  _repeatUntil == null
                      ? 'Repeat until: No end date'
                      : 'Repeat until: ${dateLabel(_repeatUntil!)}',
                ),
              ),
              if (_repeatUntil != null)
                TextButton(
                  onPressed: () => setState(() => _repeatUntil = null),
                  child: const Text('Clear end date'),
                ),
            ],
            const SizedBox(height: 18),
            Text(
              'Notify me before',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            const Text('Choose as many reminders as you need.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final minutes in offsets)
                  FilterChip(
                    label: Text(_offsetLabel(minutes)),
                    selected: _selectedOffsets.contains(minutes),
                    onSelected: (selected) => setState(
                      () => selected
                          ? _selectedOffsets.add(minutes)
                          : _selectedOffsets.remove(minutes),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    ),
  );
}

String _offsetLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h';
}

class TaskCalendarPage extends StatefulWidget {
  const TaskCalendarPage({super.key, required this.data, required this.kind});
  final LifeData data;
  final TaskKind kind;
  @override
  State<TaskCalendarPage> createState() => _TaskCalendarPageState();
}

class _TaskCalendarPageState extends State<TaskCalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.kind == TaskKind.university
            ? 'University calendar'
            : 'Planner calendar',
      ),
    ),
    body: AnimatedBuilder(
      animation: widget.data,
      builder: (context, _) {
        final selected = widget.data.occurrences(
          widget.kind,
          _selected,
          includeHistory: true,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            _MonthGrid(
              month: _month,
              selected: _selected,
              onPrevious: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              onNext: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              onSelect: (day) => setState(() => _selected = day),
              statusFor: (day) {
                final items = widget.data.occurrences(
                  widget.kind,
                  day,
                  includeHistory: true,
                );
                if (items.any(
                  (item) =>
                      item.progress?.postponedTo != null &&
                      dayKey(item.at) == item.origin,
                )) {
                  return const Color(0xFFFFB876);
                }
                if (items.any((item) => item.completed)) {
                  return const Color(0xFF9EF0C0);
                }
                return items.isEmpty ? null : const Color(0xFFB5A6FF);
              },
            ),
            const SizedBox(height: 22),
            Text(
              dateLabel(_selected),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (selected.isEmpty)
              const _EmptyTasks(label: 'Nothing recorded for this day.')
            else
              for (final item in selected)
                Card(
                  child: ListTile(
                    title: Text(item.task.title),
                    subtitle: Text(_historyStatus(item)),
                    leading: Icon(
                      item.completed
                          ? Icons.check_circle_rounded
                          : item.progress?.postponedTo != null &&
                                dayKey(item.at) == item.origin
                          ? Icons.event_repeat_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

String _historyStatus(TaskOccurrence item) {
  final state = item.progress;
  if (state?.deletedReason != null) return 'Removed: ${state!.deletedReason}';
  if (state?.postponedTo != null && dayKey(item.at) == item.origin) {
    return 'Postponed to ${dateLabel(state!.postponedTo!)}';
  }
  if (state?.completedOn != null) {
    return 'Done ${dateLabel(state!.completedOn!)}';
  }
  if (state?.postponedTo != null) {
    return 'Postponed here · ${timeLabel(item.at)}';
  }
  return 'Planned · ${timeLabel(item.at)}';
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
    required this.statusFor,
    this.labelFor,
  });
  final DateTime month;
  final DateTime selected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;
  final Color? Function(DateTime) statusFor;
  final String? Function(DateTime)? labelFor;

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(month.month)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final name in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8E96A8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < ((offset + count + 6) ~/ 7); row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final number = row * 7 + column - offset + 1;
                          if (number < 1 || number > count) {
                            return const SizedBox(height: 54);
                          }
                          final date = DateTime(
                            month.year,
                            month.month,
                            number,
                          );
                          final color = statusFor(date);
                          final isSelected = dayKey(date) == dayKey(selected);
                          return InkWell(
                            onTap: () => onSelect(date),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 54,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (color ?? const Color(0xFF9EF0C0))
                                          .withValues(alpha: 0.34)
                                    : color?.withValues(alpha: 0.17),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$number',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (labelFor?.call(date) != null)
                                    Text(
                                      labelFor!(date)!,
                                      style: const TextStyle(fontSize: 13),
                                    )
                                  else if (color != null)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
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

class GymPage extends StatefulWidget {
  const GymPage({super.key, required this.data});
  final LifeData data;
  @override
  State<GymPage> createState() => _GymPageState();
}

class _GymPageState extends State<GymPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  Future<void> _edit(DateTime date) async {
    setState(() => _selected = date);
    final key = dayKey(date);
    final result = await showModalBottomSheet<_GymEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) =>
          _GymEditor(date: date, existing: widget.data.gym[key]),
    );
    if (result == null) return;
    if (result.remove) {
      widget.data.gym.remove(key);
    } else {
      widget.data.gym[key] = result.day!;
    }
    await widget.data.persist();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gym planner')),
    body: AnimatedBuilder(
      animation: widget.data,
      builder: (context, _) {
        final plan = widget.data.gym[dayKey(_selected)];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            const Text('🫸 Push   🧗 Pull   🦵 Legs & abs'),
            const SizedBox(height: 14),
            _MonthGrid(
              month: _month,
              selected: _selected,
              onPrevious: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              onNext: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              onSelect: _edit,
              statusFor: (date) {
                switch (widget.data.gym[dayKey(date)]?.type) {
                  case 'push':
                    return const Color(0xFF8FE3B0);
                  case 'pull':
                    return const Color(0xFFFF8989);
                  case 'legs':
                    return const Color(0xFF87B7FF);
                  default:
                    return null;
                }
              },
              labelFor: (date) {
                switch (widget.data.gym[dayKey(date)]?.type) {
                  case 'push':
                    return '🫸';
                  case 'pull':
                    return '🧗';
                  case 'legs':
                    return '🦵';
                  default:
                    return null;
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              dateLabel(_selected),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: Text(
                  plan == null
                      ? 'No workout planned'
                      : '${plan.type.toUpperCase()} · ${plan.done ? 'Done' : 'Planned'}',
                ),
                subtitle: Text(
                  plan?.comment.isNotEmpty == true
                      ? plan!.comment
                      : 'Tap a day to set or update its workout.',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(_selected),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _GymEditResult {
  const _GymEditResult({this.day, this.remove = false});
  final GymDay? day;
  final bool remove;
}

class _GymEditor extends StatefulWidget {
  const _GymEditor({required this.date, this.existing});
  final DateTime date;
  final GymDay? existing;

  @override
  State<_GymEditor> createState() => _GymEditorState();
}

class _GymEditorState extends State<_GymEditor> {
  late String? _type = widget.existing?.type;
  late bool _done =
      widget.existing?.done ?? !widget.date.isAfter(dayOnly(DateTime.now()));
  late final _comment = TextEditingController(
    text: widget.existing?.comment ?? '',
  );

  @override
  void dispose() {
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
              dateLabel(widget.date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            const Text('Choose a workout'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _choice('push', '🫸 Push', const Color(0xFF8FE3B0)),
                _choice('pull', '🧗 Pull', const Color(0xFFFF8989)),
                _choice('legs', '🦵 Legs & abs', const Color(0xFF87B7FF)),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Done'),
              subtitle: const Text('Off means planned for later'),
              value: _done,
              onChanged: (value) => setState(() => _done = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _type == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _GymEditResult(
                        day: GymDay(
                          _type!,
                          _done,
                          comment: _comment.text.trim(),
                        ),
                      ),
                    ),
              child: const Text('Save workout'),
            ),
            if (widget.existing != null)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const _GymEditResult(remove: true)),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear this day'),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _choice(String value, String label, Color color) => ChoiceChip(
    label: Text(label),
    selected: _type == value,
    selectedColor: color.withValues(alpha: 0.35),
    onSelected: (_) => setState(() => _type = value),
  );
}
