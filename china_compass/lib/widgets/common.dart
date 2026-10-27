import 'package:flutter/material.dart';

import '../models/content.dart';
import '../screens/guide_screen.dart';
import '../screens/login_screen.dart';
import '../screens/search_screen.dart';
import '../state/app_state.dart';
import 'icons.dart';
import 'language_switcher.dart';

/// App bar actions for the main tabs: language and search.
List<Widget> appBarActions(BuildContext context) => [
      const LanguageButton(),
      IconButton(
        tooltip: AppScope.of(context).t('search'),
        icon: const Icon(Icons.search_rounded),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
      ),
      const SizedBox(width: 6),
    ];

/// Opens a guide; [appQuery] pre-fills the app directory search (e.g. from "Related apps").
void openGuide(BuildContext context, String id, {String? appQuery}) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => GuideScreen(guideId: id, appQuery: appQuery)));

/// Saves or removes [key]; asks the user to sign in first if needed.
Future<void> toggleSavedWithLogin(BuildContext context, String key) async {
  final state = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!state.signedIn) {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => LoginScreen(reason: state.t('signInToSave'))),
    );
    if (ok != true) return;
  }
  final wasSaved = state.isSaved(key);
  state.toggleSaved(key);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(state.t(wasSaved ? 'stepRemoved' : 'stepSaved')),
      duration: const Duration(seconds: 2),
    ));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = 28});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

/// A white rounded card holding rows separated by thin dividers (inset grouped list).
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.dividerIndent = 16});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(indent: dividerIndent),
              children[i],
            ],
          ],
        ),
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.done, required this.total, this.showLabel = true, this.color});

  final int done;
  final int total;
  final bool showLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: done / total,
            minHeight: 6,
            color: color ?? scheme.primary,
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(AppScope.of(context).t('stepsDone', {'done': done, 'total': total}),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// One guide as a row inside a [GroupedCard].
class GuideRow extends StatelessWidget {
  const GuideRow({super.key, required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.progress([guide]);
    final scheme = Theme.of(context).colorScheme;
    final complete = p.total > 0 && p.done == p.total;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      leading: IconTile(guide.id),
      title: Text(guide.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(guide.summary, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (complete)
            Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20)
          else
            Text(p.total > 0 ? '${p.done}/${p.total}' : state.t('min', {'n': guide.minutes}),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => openGuide(context, guide.id),
    );
  }
}

/// Round check used for every step: a calmer alternative to square checkboxes.
class StepCheck extends StatelessWidget {
  const StepCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? scheme.primary : Colors.transparent,
        border: Border.all(color: checked ? scheme.primary : scheme.outline, width: 1.6),
      ),
      child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }
}
