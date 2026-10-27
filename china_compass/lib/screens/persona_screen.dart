import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/language_switcher.dart';
import '../widgets/photo_card.dart';
import 'search_screen.dart';

/// A path (travel, study, life) with a large photo header and its guides below.
class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key, required this.personaId});

  final String personaId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final persona = state.content!.personas.firstWhere((p) => p.id == personaId);
    final p = state.progress(persona.guides);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            automaticallyImplyLeading: false,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            actions: [
              const LanguageButton(onImage: true),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.search_rounded,
                tooltip: state.t('search'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(photoFor(persona.id), fit: BoxFit.cover),
                  const DecoratedBox(decoration: BoxDecoration(gradient: photoScrim)),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Glass(
                          padding: const EdgeInsets.all(8),
                          radius: 14,
                          child: Icon(iconFor(persona.id), color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 12),
                        Text(persona.title,
                            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontSize: 32)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(persona.intro,
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                if (p.total > 0) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ProgressBar(done: p.done, total: p.total, color: colorFor(persona.id)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GroupedCard(
                  dividerIndent: 74,
                  children: [for (final g in persona.guides) GuideRow(guide: g)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
