import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content.dart';
import '../state/app_state.dart';
import 'app_card.dart';
import 'app_directory.dart';
import 'common.dart';
import 'icons.dart';
import 'rich_line.dart';
import 'visa_regions.dart';

/// Renders one content block of a guide. App sliders run edge to edge;
/// everything else gets the normal 16px side padding.
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.guide, required this.index, this.appQuery});

  final Guide guide;
  final int index;
  final String? appQuery;

  Block get block => guide.blocks[index];

  @override
  Widget build(BuildContext context) {
    // A slider only pays off with 3+ apps; one or two are simply listed.
    // Apps of one category, listed (no slider): icon, name, labels, GET.
    if (block.type == 'apps') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading(block.heading),
            GroupedCard(
              children: [
                for (final app in block.items) Padding(padding: const EdgeInsets.all(16), child: AppSummary(app: app)),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: switch (block.type) {
        'text' => _TextBlock(block),
        'tip' || 'warning' => _Callout(block),
        'checklist' => _Checklist(guide: guide, index: index),
        'app' => _AppSection(guide: guide, index: index),
        'info' => _InfoCard(block),
        'explore' => _Explore(block),
        'app_directory' =>
          AppDirectory(heading: block.heading, categories: block.categories, initialQuery: appQuery),
        'related_apps' => _RelatedApps(block),
        'phrases' => _Phrases(block),
        'links' => _Links(block),
        'visa_regions' => VisaRegions(
            heading: block.heading,
            intro: block.intro,
            source: block.source,
            popular: block.popular,
            regions: block.items,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text!, style: Theme.of(context).textTheme.titleLarge),
        );
}

class _TextBlock extends StatelessWidget {
  const _TextBlock(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55, fontSize: 16);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        for (final p in block.paragraphs)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: RichLine(p, style: body)),
        for (final b in block.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 12, left: 2),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: scheme.onSurfaceVariant, shape: BoxShape.circle),
                  ),
                ),
                Expanded(child: RichLine(b, style: body)),
              ],
            ),
          ),
      ],
    );
  }
}

/// All explanations of a guide in one card: short sections separated by dividers,
/// tips and warnings shown as highlighted lines inside their section.
class _InfoCard extends StatelessWidget {
  const _InfoCard(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.55, fontSize: 15.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading ?? state.t('goodToKnow')),
        GroupedCard(
          children: [
            for (final sec in block.sections)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sec['heading'] case final String heading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(heading, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16.5)),
                      ),
                    for (final p in List<String>.from(sec['paragraphs'] as List? ?? const []))
                      Padding(padding: const EdgeInsets.only(bottom: 8), child: RichLine(p, style: body)),
                    for (final b in List<String>.from(sec['bullets'] as List? ?? const []))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 9, right: 12, left: 2),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: scheme.onSurfaceVariant, shape: BoxShape.circle),
                              ),
                            ),
                            Expanded(child: RichLine(b, style: body)),
                          ],
                        ),
                      ),
                    if (sec['note'] case final Map note)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: _Note(type: note['type'] as String, text: note['text'] as String),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// App icons at the end of a guide; tapping one opens the app directory filtered to it.
class _RelatedApps extends StatelessWidget {
  const _RelatedApps(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final content = state.content!;
    final apps = [for (final id in block.appIds) ?content.findApp(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final app in apps)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => openGuide(context, block.guide ?? 'apps', appQuery: app['name'] as String),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            AppIcon(id: app['id'] as String, size: 52),
                            const SizedBox(height: 6),
                            Text(app['name'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cards that open detail pages (e.g. "WeChat in detail").
class _Explore extends StatelessWidget {
  const _Explore(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final guides = [
      for (final item in block.items)
        if (state.content!.findGuide(item['guide'] as String) case final found?) found.guide,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        GroupedCard(
          dividerIndent: 76,
          children: [
            for (final g in guides)
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                leading: g.appIcon == null ? IconTile(g.id) : AppIcon(id: g.appIcon!, size: 44),
                title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text(g.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                onTap: () => openGuide(context, g.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// A tip or warning inside an info section.
class _Note extends StatelessWidget {
  const _Note({required this.type, required this.text});

  final String type;
  final String text;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isTip = type == 'tip';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = isTip ? const Color(0xFF2E7D4F) : const Color(0xFFB26B00);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isTip ? Icons.lightbulb_outline_rounded : Icons.info_outline_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichLine(
              '**${state.t(type)}:** $text',
              style: const TextStyle(height: 1.45, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isTip = block.type == 'tip';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = isTip ? const Color(0xFF2E7D4F) : const Color(0xFFB26B00);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isTip ? Icons.lightbulb_outline_rounded : Icons.info_outline_rounded, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.t(block.type), style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                const SizedBox(height: 4),
                RichLine(block.text ?? '', style: const TextStyle(height: 1.5, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One checklist step: round check, text, optional note, and a "save for later" bookmark.
class StepRow extends StatelessWidget {
  const StepRow({super.key, required this.id, required this.item});

  final String id;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final on = state.checked.contains(id);
    final saved = state.isSaved('step:$id');
    final note = item['note'] as String?;

    return InkWell(
      onTap: () => state.toggle(id, !on),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(checked: on, child: Padding(padding: const EdgeInsets.only(top: 1), child: StepCheck(checked: on))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichLine(
                    item['text'] as String,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.4,
                      decoration: on ? TextDecoration.lineThrough : null,
                      color: on ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    RichLine(note, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5, height: 1.4)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: state.t(saved ? 'unsaveStep' : 'saveStep'),
              visualDensity: VisualDensity.compact,
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: saved ? scheme.primary : scheme.onSurfaceVariant, size: 22),
              onPressed: () => toggleSavedWithLogin(context, 'step:$id'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.guide, required this.index});

  final Guide guide;
  final int index;

  @override
  Widget build(BuildContext context) {
    final block = guide.blocks[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        GroupedCard(
          dividerIndent: 54,
          children: [
            for (var i = 0; i < block.items.length; i++) StepRow(id: guide.stepId(index, i), item: block.items[i]),
          ],
        ),
      ],
    );
  }
}

/// A single app presented on its own, with its setup steps in the same card.
class _AppSection extends StatelessWidget {
  const _AppSection({required this.guide, required this.index});

  final Guide guide;
  final int index;

  @override
  Widget build(BuildContext context) {
    final block = guide.blocks[index];
    final app = block.app!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        GroupedCard(
          dividerIndent: 54,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: AppSummary(app: app)),
            for (var i = 0; i < block.items.length; i++) StepRow(id: guide.stepId(index, i), item: block.items[i]),
          ],
        ),
      ],
    );
  }
}

/// Plays a phrase's recording (bundled with the app, so it works offline).
/// One shared player, so tapping another phrase stops the previous one.
class PlayButton extends StatefulWidget {
  const PlayButton({super.key, required this.asset});

  /// Path like `assets/audio/phrases/<id>.mp3`.
  final String asset;

  static final _player = AudioPlayer();
  static final _current = ValueNotifier<String?>(null);

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  StreamSubscription<void>? _done;

  @override
  void initState() {
    super.initState();
    _done = PlayButton._player.onPlayerComplete.listen((_) => PlayButton._current.value = null);
  }

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    PlayButton._current.value = widget.asset;
    await PlayButton._player.stop();
    // AssetSource paths are relative to assets/.
    await PlayButton._player.play(AssetSource(widget.asset.replaceFirst('assets/', '')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: PlayButton._current,
      builder: (context, playing, _) {
        final active = playing == widget.asset;
        return IconButton.filledTonal(
          tooltip: AppScope.of(context).t('playPhrase'),
          style: IconButton.styleFrom(
            backgroundColor: active ? scheme.primary : scheme.surfaceContainer,
            foregroundColor: active ? scheme.onPrimary : scheme.primary,
          ),
          icon: Icon(active ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 22),
          onPressed: _play,
        );
      },
    );
  }
}

class _Phrases extends StatelessWidget {
  const _Phrases(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading),
        GroupedCard(
          children: [
            for (final p in block.items)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (p['audio'] case final String audio) ...[
                      PlayButton(asset: audio),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(p['zh'] as String,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, locale: Locale('zh', 'CN'))),
                          const SizedBox(height: 2),
                          Text(p['pinyin'] as String, style: TextStyle(color: scheme.primary, fontSize: 14.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(p['meaning'] as String,
                          textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  const _Links(this.block);

  final Block block;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(block.heading ?? state.t('officialLinks')),
        GroupedCard(
          children: [
            for (final l in block.items)
              ListTile(
                title: Text(l['label'] as String, style: const TextStyle(fontSize: 15.5)),
                trailing: Icon(Icons.north_east_rounded, size: 18, color: scheme.onSurfaceVariant),
                onTap: () => launchUrl(Uri.parse(l['url'] as String), mode: LaunchMode.externalApplication),
              ),
          ],
        ),
      ],
    );
  }
}
