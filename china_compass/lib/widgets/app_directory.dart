import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'app_card.dart';
import 'common.dart';

/// All apps in one place: a search field, category filter chips, and one list per
/// category. Search matches app names, descriptions, categories and labels
/// (e.g. "translation", "english", "must-have").
class AppDirectory extends StatefulWidget {
  const AppDirectory({super.key, required this.heading, required this.categories, this.initialQuery});

  final String? heading;

  /// Pre-filled search, e.g. when coming from a "Related apps" icon.
  final String? initialQuery;

  /// `{id, name, apps: [...]}` per category, in display order.
  final List<Map<String, dynamic>> categories;

  @override
  State<AppDirectory> createState() => _AppDirectoryState();
}

class _AppDirectoryState extends State<AppDirectory> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery ?? '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? _category; // null = all

  static bool _hasAll(String text, String q) => q.split(RegExp(r'\s+')).every(text.toLowerCase().contains);

  bool _matchesName(Map<String, dynamic> app, String q) => _hasAll(app['name'] as String, q);

  bool _matchesAnything(AppState state, Map<String, dynamic> category, Map<String, dynamic> app, String q) {
    final tags = List<String>.from(app['tags'] as List? ?? const []);
    return _hasAll(
      [app['name'], app['desc'], category['name'], for (final t in tags) state.t(AppTag.labelKey(t) ?? '')].join(' '),
      q,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();

    // If the query names an app, show just those apps; otherwise search everything
    // (descriptions, categories, labels such as "english" or "vpn needed").
    final all = [
      for (final c in widget.categories)
        for (final a in c['apps'] as List) (category: c, app: Map<String, dynamic>.from(a as Map)),
    ];
    final byName = q.isNotEmpty && all.any((e) => _matchesName(e.app, q));
    bool keep(({Map<String, dynamic> category, Map<String, dynamic> app}) e) =>
        q.isEmpty || (byName ? _matchesName(e.app, q) : _matchesAnything(state, e.category, e.app, q));

    final groups = [
      for (final c in widget.categories)
        if (_category == null || _category == c['id'])
          (category: c, apps: [for (final e in all) if (e.category == c && keep(e)) e.app]),
    ].where((g) => g.apps.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.heading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.heading!, style: theme.textTheme.titleLarge),
          ),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: state.t('appSearch'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        // Category filter, scrollable sideways.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: state.t('appFilterAll'),
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in widget.categories)
                _FilterChip(
                  label: c['name'] as String,
                  selected: _category == c['id'],
                  onTap: () => setState(() => _category = _category == c['id'] ? null : c['id'] as String),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(state.t('noApps', {'q': _query.trim()}))),
          ),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(g.category['name'] as String, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16.5)),
          ),
          GroupedCard(
            children: [
              for (final app in g.apps) Padding(padding: const EdgeInsets.all(16), child: AppSummary(app: app)),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLowest,
        shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
