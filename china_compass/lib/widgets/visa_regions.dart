import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import 'rich_line.dart';

/// Rule codes used in content files, in the order they're shown.
const _rules = ['free30', 'free15', 'mutual', 'transit'];

Color _ruleColor(String rule) => switch (rule) {
      'free30' || 'free15' => const Color(0xFF2E7D4F),
      'mutual' => const Color(0xFF2F6FB0),
      _ => const Color(0xFFB26B00),
    };

/// Turns an ISO country code into its flag emoji (regional indicator symbols).
String flagEmoji(String code) =>
    String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Visa rules by nationality: a short transit note and a search field on top,
/// then one section per region with countries grouped by the rule that applies.
/// Every country links to its official source (the Chinese embassy there).
class VisaRegions extends StatefulWidget {
  const VisaRegions({super.key, required this.heading, required this.regions, this.intro, this.source});

  final String? heading;
  final String? intro;

  /// General official page, shown under the search field.
  final String? source;
  final List<Map<String, dynamic>> regions;

  @override
  State<VisaRegions> createState() => _VisaRegionsState();
}

class _VisaRegionsState extends State<VisaRegions> {
  String _query = '';

  List<Map<String, dynamic>> _countries(Map<String, dynamic> region) =>
      List<Map<String, dynamic>>.from(region['countries'] as List);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            for (final r in widget.regions)
              for (final c in _countries(r))
                if ((c['name'] as String).toLowerCase().contains(q)) c,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.heading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.heading!, style: theme.textTheme.titleLarge),
          ),
        if (widget.intro != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.connecting_airports_rounded, color: theme.colorScheme.tertiary, size: 22),
                const SizedBox(width: 12),
                Expanded(child: RichLine(widget.intro!, style: const TextStyle(height: 1.5, fontSize: 14.5))),
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
        if (widget.source != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _open(widget.source!),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(state.t('visaOfficialSource'), style: const TextStyle(fontSize: 13)),
            ),
          )
        else
          const SizedBox(height: 12),
        if (q.isNotEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: matches.isEmpty
                ? Padding(
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
                  )
                : Column(
                    children: [
                      for (final c in matches.take(6))
                        ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          leading: Text(flagEmoji(c['code'] as String), style: const TextStyle(fontSize: 26)),
                          title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.t('rule_${c['rule']}'),
                                  style: TextStyle(color: _ruleColor(c['rule'] as String), fontWeight: FontWeight.w600)),
                              if (c['source'] != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _open(c['source'] as String),
                                  icon: const Icon(Icons.north_east_rounded, size: 16),
                                  label: Text(state.t('visaCheckRules')),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          )
        else
          for (var i = 0; i < widget.regions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RegionCard(
                name: widget.regions[i]['name'] as String,
                countries: _countries(widget.regions[i]),
                initiallyExpanded: i == 0,
              ),
            ),
      ],
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.name, required this.countries, required this.initiallyExpanded});

  final String name;
  final List<Map<String, dynamic>> countries;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final free = countries.where((c) => c['rule'] != 'transit').length;
    final transit = countries.length - free;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          subtitle: Text(state.t('regionSummary', {'free': free, 'transit': transit}),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          children: [
            for (final rule in _rules)
              if (countries.where((c) => c['rule'] == rule).toList() case final group when group.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: _ruleColor(rule), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.t('rule_$rule'),
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _ruleColor(rule))),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in group)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${flagEmoji(c['code'] as String)}  ${c['name']}',
                                  style: const TextStyle(fontSize: 13.5)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
