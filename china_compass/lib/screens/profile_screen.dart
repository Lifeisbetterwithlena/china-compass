import 'package:flutter/material.dart';

import '../state/account_sync.dart';
import '../state/app_state.dart';
import '../widgets/blocks.dart';
import '../widgets/common.dart';
import '../widgets/language_switcher.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(state.t('tabProfile')), actions: const [LanguageButton(), SizedBox(width: 10)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          if (state.signedIn) ..._signedIn(context, state) else _SignedOut(state: state),
          SectionLabel(state.t('settings')),
          const LanguageTile(),
          if (state.signedIn) ...[
            const SizedBox(height: 10),
            GroupedCard(
              dividerIndent: 56,
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(state.t('signOut')),
                  onTap: () => state.signOut(),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                  title: Text(state.t('deleteAccount'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () => _confirmDelete(context, state),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = state.content!;
    final email = state.auth.email!;
    final all = state.progress(content.allGuides);

    final steps = [
      for (final key in state.saved)
        if (key.startsWith('step:'))
          if (content.findStep(key.substring(5)) case final s?) (id: key.substring(5), guide: s.guide, item: s.item),
    ];
    final guides = [
      for (final key in state.saved)
        if (key.startsWith('guide:'))
          if (content.findGuide(key.substring(6)) case final g?) g.guide,
    ];

    // Group saved steps by guide, in content order.
    final byGuide = <String, List<({String id, Map<String, dynamic> item})>>{};
    for (final g in content.allGuides) {
      final list = [
        for (final s in steps)
          if (s.guide.id == g.id) (id: s.id, item: s.item),
      ]..sort((a, b) => a.id.compareTo(b.id));
      if (list.isNotEmpty) byGuide[g.id] = list;
    }

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Text(email[0].toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.primary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    _SyncLine(state: state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _Stat(value: '${all.done}', label: state.t('statDone'))),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: '${state.saved.length}', label: state.t('statSaved'))),
        ],
      ),
      SectionLabel(state.t('savedSteps')),
      if (byGuide.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.bookmark_border_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(state.t('savedEmpty'), style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45))),
            ]),
          ),
        )
      else
        for (final entry in byGuide.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: InkWell(
              onTap: () => openGuide(context, entry.key),
              child: Row(children: [
                Expanded(
                  child: Text(content.findGuide(entry.key)!.guide.title,
                      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
          GroupedCard(
            dividerIndent: 54,
            children: [for (final s in entry.value) StepRow(id: s.id, item: s.item)],
          ),
          const SizedBox(height: 10),
        ],
      if (guides.isNotEmpty) ...[
        SectionLabel(state.t('savedGuides'), top: 18),
        GroupedCard(dividerIndent: 72, children: [for (final g in guides) GuideRow(guide: g)]),
      ],
    ];
  }
}

Future<void> _confirmDelete(BuildContext context, AppState state) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(state.t('deleteAccountTitle')),
      content: Text(state.t('deleteAccountText')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(state.t('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(state.t('deleteAccountConfirm')),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await state.deleteAccount();
    messenger.showSnackBar(SnackBar(content: Text(state.t('accountDeleted'))));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(state.t('deleteFailed'))));
  }
}

/// Where the user's progress is: saved to the account, being saved, or waiting for a connection.
class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (icon, key, color) = switch (state.syncStatus) {
      SyncStatus.synced => (Icons.cloud_done_outlined, 'syncSynced', const Color(0xFF2E7D4F)),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, 'syncSyncing', muted),
      SyncStatus.pending => (Icons.cloud_off_outlined, 'syncPending', const Color(0xFFB26B00)),
      _ => (Icons.phone_iphone_rounded, 'demoAccount', muted),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 6),
        Expanded(child: Text(state.t(key), style: TextStyle(color: color, fontSize: 13, height: 1.35))),
      ],
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.bookmarks_outlined, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(state.t('profileSignedOutTitle'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(state.t('profileSignedOutText'),
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => const LoginScreen()),
              ),
              child: Text(state.t('signIn')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}
