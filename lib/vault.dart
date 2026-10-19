import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lajf_app/life_data.dart';

class VaultPasswordDialog extends StatefulWidget {
  const VaultPasswordDialog({super.key, this.setup = false});
  final bool setup;

  @override
  State<VaultPasswordDialog> createState() => _VaultPasswordDialogState();
}

class _VaultPasswordDialogState extends State<VaultPasswordDialog> {
  final _controller = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.setup &&
        (_controller.text.runes.length < 12 ||
            _controller.text.trim().isEmpty)) {
      setState(() => _error = 'Use at least 12 characters.');
      return;
    }
    if (widget.setup && _controller.text != _confirmation.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.setup ? 'Set vault password' : 'Private access'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.setup)
            const Text(
              'Choose a unique password with at least 12 characters. '
              'There is no password recovery.',
            ),
          TextField(
            controller: _controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) {
              if (!widget.setup) _submit();
            },
          ),
          if (widget.setup)
            TextField(
              controller: _confirmation,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        onPressed: _submit,
        child: Text(widget.setup ? 'Create password' : 'Unlock'),
      ),
    ],
  );
}

class VaultCard {
  const VaultCard({
    required this.id,
    required this.name,
    required this.pin,
    this.comment = '',
  });

  final String id;
  final String name;
  final String pin;
  final String comment;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'pin': pin,
    'comment': comment,
  };

  factory VaultCard.fromJson(Map<String, dynamic> json) => VaultCard(
    id: json['id'] as String,
    name: json['name'] as String,
    pin: json['pin'] as String,
    comment: json['comment'] as String? ?? '',
  );
}

class VaultStore {
  VaultStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'lajf_vault_cards_v1';
  final FlutterSecureStorage _storage;

  Future<List<VaultCard>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => VaultCard.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<VaultCard> cards) => _storage.write(
    key: _key,
    value: jsonEncode(cards.map((card) => card.toJson()).toList()),
  );
}

class VaultPage extends StatefulWidget {
  const VaultPage({super.key, this.store});
  final VaultStore? store;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> with WidgetsBindingObserver {
  late final VaultStore _store = widget.store ?? VaultStore();
  List<VaultCard> _cards = [];
  final Set<String> _visibleIds = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await _store.load();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open your card vault.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _visibleIds.clear();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _save(List<VaultCard> updated) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.save(updated);
      if (!mounted) return;
      setState(() => _cards = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this card. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([VaultCard? card]) async {
    if (_loading || _saving || _error != null) return;
    final updated = await showModalBottomSheet<VaultCard>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B25),
      builder: (context) => _VaultCardEditor(card: card),
    );
    if (updated == null || !mounted) return;
    final cards = [..._cards];
    final index = cards.indexWhere((item) => item.id == updated.id);
    if (index < 0) {
      cards.add(updated);
    } else {
      cards[index] = updated;
    }
    await _save(cards);
  }

  Future<void> _remove(VaultCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove card?'),
        content: Text('Remove ${card.name} and its PIN from this phone?'),
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
    _visibleIds.remove(card.id);
    await _save(_cards.where((item) => item.id != card.id).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Card vault')),
    floatingActionButton: _loading || _error != null
        ? null
        : FloatingActionButton(
            onPressed: _saving ? null : () => _edit(),
            tooltip: 'Add card',
            child: const Icon(Icons.add_rounded),
          ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _cards.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    size: 48,
                    color: Color(0xFF9EF0C0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No cards yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first card.'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Text(
                  'Your cards',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                for (final card in _cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.credit_card_rounded,
                                  color: Color(0xFF9EF0C0),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    card.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Card options',
                                  onSelected: (value) => value == 'edit'
                                      ? _edit(card)
                                      : _remove(card),
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _visibleIds.contains(card.id)
                                        ? card.pin
                                        : '••••',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() {
                                    if (!_visibleIds.add(card.id)) {
                                      _visibleIds.remove(card.id);
                                    }
                                  }),
                                  icon: Icon(
                                    _visibleIds.contains(card.id)
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  tooltip: _visibleIds.contains(card.id)
                                      ? 'Hide PIN'
                                      : 'Show PIN',
                                ),
                              ],
                            ),
                            if (card.comment.isNotEmpty)
                              Text(
                                card.comment,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _VaultCardEditor extends StatefulWidget {
  const _VaultCardEditor({this.card});
  final VaultCard? card;

  @override
  State<_VaultCardEditor> createState() => _VaultCardEditorState();
}

class _VaultCardEditorState extends State<_VaultCardEditor> {
  late final _name = TextEditingController(text: widget.card?.name ?? '');
  late final _pin = TextEditingController(text: widget.card?.pin ?? '');
  late final _comment = TextEditingController(text: widget.card?.comment ?? '');
  bool _showPin = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _pin.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a card name and PIN.')),
      );
      return;
    }
    Navigator.pop(
      context,
      VaultCard(
        id: widget.card?.id ?? newId(),
        name: _name.text.trim(),
        pin: _pin.text.trim(),
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
              widget.card == null ? 'Add card' : 'Edit card',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Card / bank name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 12,
              obscureText: !_showPin,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'PIN',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPin = !_showPin),
                  icon: Icon(
                    _showPin
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
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
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Save card')),
          ],
        ),
      ),
    ),
  );
}
