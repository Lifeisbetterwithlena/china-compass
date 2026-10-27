import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'flag.dart';

// Language switching follows common best practice:
// - always reachable from the top bar, on every screen
// - flag plus the language's own name (endonym), never a flag alone
// - the picker title is bilingual, so it's recognizable whatever language is active
// - the choice applies instantly, is remembered, and defaults to the device language

/// Compact pill for the app bar: flag, language code and a chevron.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onImage = false});

  /// Translucent white style for use on top of photos.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    if (enabledLanguages.length < 2) return const SizedBox.shrink();
    final state = AppScope.of(context);
    final current = languageFor(state.lang);
    final scheme = Theme.of(context).colorScheme;
    final fg = onImage ? Colors.white : scheme.onSurface;

    return Semantics(
      button: true,
      label: state.t('currentLanguage', {'name': current.nativeName}),
      excludeSemantics: true,
      child: Tooltip(
        message: 'Language · Sprache · Idioma',
        child: Material(
          color: onImage ? Colors.white.withValues(alpha: 0.22) : scheme.surfaceContainerLowest,
          shape: StadiumBorder(
            side: BorderSide(color: onImage ? Colors.white.withValues(alpha: 0.35) : scheme.outlineVariant),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showLanguagePicker(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flag(current.flag, width: 22),
                    const SizedBox(width: 7),
                    Text(current.code.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5, color: fg)),
                    Icon(Icons.expand_more_rounded, size: 18, color: fg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width row for the home screen, opening the same picker.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (enabledLanguages.length < 2) return const SizedBox.shrink();
    final state = AppScope.of(context);
    final current = languageFor(state.lang);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(state.t('language')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flag(current.flag, width: 24),
            const SizedBox(width: 8),
            Text(current.nativeName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => showLanguagePicker(context),
      ),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) {
  final state = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.language, color: scheme.primary),
                const SizedBox(width: 10),
                // Bilingual on purpose: findable even if the current language can't be read.
                Expanded(child: Text('Language · Sprache · Idioma', style: Theme.of(sheetContext).textTheme.titleLarge)),
              ]),
              const SizedBox(height: 4),
              Text(state.t('languageHint'), style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: state.lang,
                onChanged: (code) async {
                  if (code == null) return;
                  Navigator.pop(sheetContext);
                  if (code == state.lang) return;
                  await state.setLang(code);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(state.t('languageChanged')),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                },
                child: Column(
                  children: [
                    for (final lang in enabledLanguages) _LanguageOption(lang: lang, selected: lang.code == state.lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.lang, required this.selected});

  final AppLanguage lang;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: RadioListTile<String>(
          value: lang.code,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          secondary: Flag(lang.flag, width: 36),
          title: Text(
            lang.nativeName,
            // Mark the name with its own locale so screen readers pronounce it correctly.
            locale: lang.locale,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          subtitle: lang.nativeName == lang.englishName ? null : Text(lang.englishName),
        ),
      ),
    );
  }
}
