import 'package:flutter/material.dart';

import '../models/content.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/language_switcher.dart';
import '../widgets/photo_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenPersona});

  final ValueChanged<String> onOpenPersona;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pager = PageController(viewportFraction: 0.84);
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goTo(int i) => _pager.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final content = state.content!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final personas = content.personas;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // Header: title with a gold accent bar, language and search on the right.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold accent bar as tall as the title, however many lines it takes.
                  Expanded(
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            margin: const EdgeInsets.only(top: 4, bottom: 4, right: 14),
                            decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(2)),
                          ),
                          Expanded(child: Text(state.t('heroTitle'), style: theme.textTheme.headlineLarge)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LanguageButton(),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.search_rounded,
                    tooltip: state.t('search'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 10, 24, 0),
              child: Text(state.t('heroText'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
            ),
            const SizedBox(height: 20),

            // Tabs synced with the photo slider.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < personas.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _goTo(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Text(
                                state.t('tab${personas[i].id[0].toUpperCase()}${personas[i].id.substring(1)}'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: i == _page ? FontWeight.w700 : FontWeight.w500,
                                  color: i == _page ? scheme.onSurface : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 5),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: i == _page ? 6 : 0,
                                height: 6,
                                decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 400,
              child: PageView.builder(
                controller: _pager,
                padEnds: false,
                itemCount: personas.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.only(left: 20, right: i == personas.length - 1 ? 20 : 0),
                  child: _PathCard(persona: personas[i], onTap: () => widget.onOpenPersona(personas[i].id)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(state.t('startHere')),
                  GroupedCard(
                    dividerIndent: 74,
                    children: [
                      for (final id in content.featured)
                        if (content.findGuide(id) case final found?) GuideRow(guide: found.guide),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    state.t('disclaimer', {'date': content.updated}),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onTap),
    );
  }
}

/// Large photo card for one path (travel, study, life).
class _PathCard extends StatelessWidget {
  const _PathCard({required this.persona, required this.onTap});

  final Persona persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.progress(persona.guides);
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Material(
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(photoFor(persona.id), fit: BoxFit.cover),
              const DecoratedBox(decoration: BoxDecoration(gradient: photoScrim)),
              // Top: icon chip and number of guides.
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Glass(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconFor(persona.id), color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(state.t('guidesCount', {'n': persona.guides.length}),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (p.total > 0)
                      Glass(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('${p.done}/${p.total}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              // Bottom: title, tagline, call to action.
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(persona.title,
                        style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(persona.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 11, 12, 11),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.t('explore'),
                                  style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: ink, size: 18),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (p.total > 0)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: p.done / p.total,
                              strokeWidth: 4,
                              strokeCap: StrokeCap.round,
                              color: gold,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
