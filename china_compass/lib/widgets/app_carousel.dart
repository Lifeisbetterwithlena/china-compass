import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';

/// One category of apps as a horizontal slider of cards (real app icon, name,
/// description, badges, App Store button).
class AppCarousel extends StatefulWidget {
  const AppCarousel({super.key, required this.heading, required this.apps});

  final String? heading;
  final List<Map<String, dynamic>> apps;

  @override
  State<AppCarousel> createState() => _AppCarouselState();
}

class _AppCarouselState extends State<AppCarousel> {
  final _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) =>
      _controller.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.apps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text(widget.heading ?? '', style: theme.textTheme.titleLarge)),
              if (count > 1) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _page < count - 1 ? () => _goTo(_page + 1) : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 214,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: count,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(left: 16, right: i == count - 1 ? 16 : 0),
              child: Card(
                child: Padding(padding: const EdgeInsets.all(16), child: AppSummary(app: widget.apps[i], expand: true)),
              ),
            ),
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Icon, name, "Get" button, description and badges for one app.
/// Used in slider cards and in single-app sections.
class AppSummary extends StatelessWidget {
  const AppSummary({super.key, required this.app, this.expand = false});

  final Map<String, dynamic> app;

  /// In a fixed-height slider card the description takes the remaining space.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badges = List<String>.from(app['badges'] as List? ?? const []);
    final link = appStoreLink(app, state.lang);
    final url = link?.url;
    final desc = Text(app['desc'] as String,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: scheme.onSurfaceVariant, fontSize: 14.5),
        overflow: TextOverflow.fade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
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
        const SizedBox(height: 12),
        if (expand) Expanded(child: desc) else desc,
        if (link != null && !link.available) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB26B00)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(state.t('chinaStoreOnly'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFB26B00), height: 1.35)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// App Store country for each app language: English → US, German → Germany, Spanish → Spain.
const _storeFor = {'en': 'us', 'de': 'de', 'es': 'es'};

/// Install link in the App Store of the selected language. Content lists the stores
/// (`stores`) where the app exists; if it's missing there, the link goes to the
/// Chinese App Store, the only place left to get it.
({String url, bool available})? appStoreLink(Map<String, dynamic> app, String lang) {
  final url = app['url'] as String?;
  final id = url == null ? null : RegExp(r'id(\d+)').firstMatch(url)?[1];
  if (id == null) return url == null ? null : (url: url, available: true);
  final store = _storeFor[lang] ?? 'us';
  final stores = app['stores'] as List?;
  final available = stores == null || stores.contains(store);
  return (url: 'https://apps.apple.com/${available ? store : 'cn'}/app/id$id', available: available);
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
