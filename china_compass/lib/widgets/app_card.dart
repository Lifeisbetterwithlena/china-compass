import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import 'common.dart';

/// Icon, name, "Get" button, description and badges for one app.
/// Used in app lists, the app directory and single-app sections.
class AppSummary extends StatelessWidget {
  const AppSummary({super.key, required this.app});

  final Map<String, dynamic> app;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Older content files use free-text badges; current ones use tag codes shown as chips.
    final badges = List<String>.from(app['badges'] as List? ?? const []);
    final link = appStoreLink(app, state.lang);
    final tags = [
      ...List<String>.from(app['tags'] as List? ?? const []),
      if (link != null && !link.available) 'chinaStore',
    ];
    final url = link?.url;
    final desc = Text(app['desc'] as String,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: scheme.onSurfaceVariant, fontSize: 14.5),
        overflow: TextOverflow.fade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AppIcon(id: app['id'] as String, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app['name'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (badges.isNotEmpty)
                    Text(badges.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (url != null) ...[
              const SizedBox(width: 8),
              // App Store-style "Get" pill, familiar to iPhone users.
              FilledButton.tonal(
                // On an iPhone, apps.apple.com links open the App Store app directly on the install page.
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: scheme.surfaceContainer,
                  foregroundColor: scheme.primary,
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                child: Semantics(label: state.t('openAppStore'), child: Text(state.t('getApp'))),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        desc,
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) AppTag(t)]),
        ],
        // Apps explained in their own guide link there instead of repeating the steps.
        if (app['guide'] case final String guideId)
          if (state.content?.findGuide(guideId) case final found?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => openGuide(context, guideId),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(state.t('setUpIn', {'guide': found.guide.title})),
              ),
            ),
      ],
    );
  }
}

/// Small label with an icon: must-have, English available, China App Store only, ...
class AppTag extends StatelessWidget {
  const AppTag(this.code, {super.key});

  final String code;

  static const _gold = Color(0xFFC98A00);
  static const _blue = Color(0xFF2F6FED);
  static const _amber = Color(0xFFB26B00);
  static const _teal = Color(0xFF12857A);
  static const _grey = Color(0xFF6B6F80);

  /// Tag code → (icon, color, text key). `null` icon means the "中" glyph.
  static const _tags = <String, (IconData?, Color, String)>{
    'must': (Icons.star_rounded, _gold, 'tagMust'),
    'nice': (Icons.star_outline_rounded, _grey, 'tagNice'),
    'english': (Icons.translate_rounded, _blue, 'tagEnglish'),
    'chinese': (null, _grey, 'tagChinese'),
    'chinaStore': (Icons.storefront_rounded, _amber, 'tagChinaStore'),
    'cards': (Icons.credit_card_rounded, _teal, 'tagCards'),
    'offline': (Icons.wifi_off_rounded, _teal, 'tagOffline'),
    'novpn': (Icons.check_circle_outline_rounded, _teal, 'tagNoVpn'),
    'vpn': (Icons.vpn_lock_rounded, _amber, 'tagVpn'),
    'official': (Icons.verified_rounded, _blue, 'tagOfficial'),
  };

  /// Text key of a tag code, for search.
  static String? labelKey(String code) => _tags[code]?.$3;

  @override
  Widget build(BuildContext context) {
    final spec = _tags[code];
    if (spec == null) return const SizedBox.shrink();
    final (icon, color, key) = spec;
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            Text('中', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color, height: 1.2)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(state.t(key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
    // The App Store chip explains itself on long-press / hover.
    return code == 'chinaStore' ? Tooltip(message: state.t('chinaStoreOnly'), child: chip) : chip;
  }
}

/// App Store country for each app language: English → US, German → Germany, Spanish → Spain.
/// App Store countries checked per app language. English speakers come from many
/// countries, so an app counts as available if it's in the US or UK store, and the
/// link opens the user's own store.
const _storesFor = {
  'en': ['us', 'gb'],
  'de': ['de'],
  'es': ['es'],
};

/// Install link for the selected language. Content lists the stores (`stores`) where
/// the app exists; if it's missing in all of them, the link goes to the Chinese App
/// Store, the only place left to get it.
({String url, bool available})? appStoreLink(Map<String, dynamic> app, String lang) {
  final url = app['url'] as String?;
  final id = url == null ? null : RegExp(r'id(\d+)').firstMatch(url)?[1];
  if (id == null) return url == null ? null : (url: url, available: true);
  final checked = _storesFor[lang] ?? const ['us', 'gb'];
  final stores = app['stores'] as List?;
  final available = stores == null || checked.any(stores.contains);
  if (!available) return (url: 'https://apps.apple.com/cn/app/id$id', available: false);
  // One store for the language: link to it; several: let the App Store pick the user's own.
  final path = checked.length == 1 ? '${checked.first}/' : '';
  return (url: 'https://apps.apple.com/${path}app/id$id', available: true);
}

/// The real app icon from `assets/app_icons/<id>.png`, with iOS-style rounded corners.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.id, this.size = 56});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/app_icons/$id.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(Icons.apps, size: size * 0.5),
        ),
      ),
    );
  }
}
