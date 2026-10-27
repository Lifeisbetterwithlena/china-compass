import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/app_card.dart';
import '../widgets/blocks.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/language_switcher.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guideId, this.appQuery});

  final String guideId;

  /// Pre-filled search for the app directory on this page.
  final String? appQuery;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final content = state.content!;
    final found = content.findGuide(guideId);
    if (found == null) return Scaffold(appBar: AppBar());

    final (:persona, :guide) = found;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final siblings = persona?.guides ?? const [];
    final idx = siblings.indexOf(guide);
    final next = idx >= 0 && idx + 1 < siblings.length ? siblings[idx + 1] : null;
    final saved = state.isSaved('guide:${guide.id}');
    final p = state.progress([guide]);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: state.t(saved ? 'unsaveStep' : 'saveGuide'),
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? scheme.primary : null),
            onPressed: () => toggleSavedWithLogin(context, 'guide:${guide.id}'),
          ),
          const LanguageButton(),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (guide.appIcon case final app?) AppIcon(id: app, size: 52) else IconTile(guide.id, size: 48),
                const SizedBox(height: 14),
                Text(guide.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(guide.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
                const SizedBox(height: 10),
                Text(state.t('readMeta', {'n': guide.minutes, 'date': content.updated}),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (p.total > 0) ...[
                  const SizedBox(height: 14),
                  ProgressBar(done: p.done, total: p.total),
                ],
              ],
            ),
          ),
          for (var i = 0; i < guide.blocks.length; i++) BlockView(guide: guide, index: i, appQuery: appQuery),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  leading: IconTile(next.id),
                  title: Text(state.t('nextGuide'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  subtitle: Text(next.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                  trailing: Icon(Icons.arrow_forward_rounded, color: scheme.primary),
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => GuideScreen(guideId: next.id)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
