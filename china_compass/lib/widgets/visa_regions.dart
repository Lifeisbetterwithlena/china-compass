import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import 'common.dart';
import 'rich_line.dart';

Color _ruleColor(String rule) => switch (rule) {
      'free30' || 'free15' => const Color(0xFF2E7D4F),
      'mutual' => const Color(0xFF2F6FB0),
      _ => const Color(0xFFB26B00),
    };

/// Turns an ISO country code into its flag emoji (regional indicator symbols).
String flagEmoji(String code) =>
    String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Folds accents so "Osterreich" finds "Österreich" and sorting ignores diacritics.
String _fold(String s) {
  const from = 'áàâäãåéèêëíìîïóòôöõúùûüñçÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ';
  const to = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

/// Visa rules by nationality: a short transit note, a search field and the most
/// common nationalities. All countries appear when searching or on request.
/// Every country links to its official source (the Chinese embassy there).
class VisaRegions extends StatefulWidget {
  const VisaRegions({
    super.key,
    required this.heading,
    required this.regions,
    this.intro,
    this.source,
    this.popular = const [],
  });

  final String? heading;
  final String? intro;

  /// General official page, shown under the search field.
  final String? source;

  /// Country codes shown before searching.
  final List<String> popular;

  /// Countries grouped by region in the content file; shown here as one list.
  final List<Map<String, dynamic>> regions;

  @override
  State<VisaRegions> createState() => _VisaRegionsState();
}

class _VisaRegionsState extends State<VisaRegions> {
  String _query = '';
  bool _showAll = false;

  List<Map<String, dynamic>> get _countries => [
        for (final r in widget.regions)
          for (final c in r['countries'] as List) Map<String, dynamic>.from(c as Map),
      ]..sort((a, b) => _fold(a['name'] as String).compareTo(_fold(b['name'] as String)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final all = _countries;
    final q = _fold(_query.trim());
    final byCode = {for (final c in all) c['code'] as String: c};

    final List<Map<String, dynamic>> shown;
    if (q.isNotEmpty) {
      shown = [for (final c in all) if (_fold(c['name'] as String).contains(q)) c];
    } else if (_showAll) {
      shown = all;
    } else {
      shown = [for (final code in widget.popular) ?byCode[code]];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.heading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.heading!, style: theme.textTheme.titleLarge),
          ),
        if (widget.intro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.connecting_airports_rounded, color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichLine(widget.intro!,
                      style: TextStyle(height: 1.5, fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        TextField(
          decoration: InputDecoration(
            hintText: state.t('visaSearch'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        if (q.isNotEmpty && shown.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.t('visaNoMatch'), style: const TextStyle(height: 1.45)),
                  if (widget.source != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _open(widget.source!),
                      icon: const Icon(Icons.north_east_rounded, size: 16),
                      label: Text(state.t('visaCheckRules')),
                    ),
                ],
              ),
            ),
          )
        else ...[
          if (q.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(state.t(_showAll ? 'visaAllCountries' : 'visaPopular'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
            ),
          GroupedCard(
            dividerIndent: 60,
            children: [for (final c in shown) _CountryRow(country: c)],
          ),
        ],
        if (q.isEmpty)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_showAll ? state.t('visaShowLess') : state.t('visaShowAll', {'n': all.length})),
            ),
          ),
        if (widget.source != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _open(widget.source!),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(state.t('visaOfficialSource'), style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }
}

/// One nationality: flag, name, the rule that applies, and a link to the official source.
class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.country});

  final Map<String, dynamic> country;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rule = country['rule'] as String;
    final source = country['source'] as String?;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: Text(flagEmoji(country['code'] as String), style: const TextStyle(fontSize: 24)),
      title: Text(country['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      subtitle: Text(state.t('rule_$rule'),
          style: TextStyle(color: _ruleColor(rule), fontWeight: FontWeight.w600, fontSize: 13)),
      trailing: source == null
          ? null
          : IconButton(
              tooltip: state.t('visaCheckRules'),
              icon: Icon(Icons.north_east_rounded, size: 18, color: Theme.of(context).colorScheme.tertiary),
              onPressed: () => _open(source),
            ),
      onTap: source == null ? null : () => _open(source),
    );
  }
}
