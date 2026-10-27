import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.trim().toLowerCase();
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final hits = terms.isEmpty
        ? const []
        : state.content!.allGuides.where((g) => terms.every(g.searchText.contains)).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: state.t('searchPlaceholder'),
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (terms.isNotEmpty && hits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(state.t('noResults', {'q': _query.trim()}), textAlign: TextAlign.center),
            ),
          if (hits.isNotEmpty)
            GroupedCard(dividerIndent: 72, children: [for (final g in hits) GuideRow(guide: g)]),
        ],
      ),
    );
  }
}
