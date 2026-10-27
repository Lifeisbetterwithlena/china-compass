import 'package:china_compass/main.dart';
import 'package:china_compass/screens/guide_screen.dart';
import 'package:china_compass/services/auth_service.dart';
import 'package:china_compass/state/app_state.dart';
import 'package:china_compass/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpApp(WidgetTester tester, String lang, {double height = 812, double width = 375}) async {
  // Set the window size (what the app sees via MediaQuery), not just the drawing area.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'lang': lang});
  late AppState state;
  await tester.runAsync(() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppState(prefs, DemoAuthService(prefs));
    await state.load();
  });
  await tester.pumpWidget(AppScope(state: state, child: const ChinaCompassApp()));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _openGuide(WidgetTester tester, String id) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).push(
    MaterialPageRoute(builder: (_) => GuideScreen(guideId: id)),
  );
  await tester.pumpAndSettle();
}

/// Lets real async work (demo login delays) finish inside a widget test.
Future<void> _settleAsync(WidgetTester tester, Future<void> Function() action) async {
  await tester.runAsync(() async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 900));
  });
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'de', 'es']) {
    testWidgets('every guide renders without overflow at phone width ($lang)', (tester) async {
      // A very tall surface so every block of a guide gets built and laid out.
      final state = await _pumpApp(tester, lang, height: 20000);
      for (final guide in state.content!.allGuides) {
        await _openGuide(tester, guide.id);
        expect(tester.takeException(), isNull, reason: 'guide ${guide.id} ($lang)');
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
    });
  }

  for (final width in [768.0, 1024.0, 1440.0]) {
    testWidgets('wide layout at ${width.toInt()} px: every page renders without overflow', (tester) async {
      final state = await _pumpApp(tester, 'en', width: width, height: 12000);
      final wide = width >= 900;
      expect(find.text('China Compass'), wide ? findsOneWidget : findsNothing, reason: 'side navigation title');
      expect(find.byType(PageView), findsNothing, reason: 'paths side by side from tablet width on');
      for (final tab in ['Travel', 'Study', 'Life', 'Profile']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab tab at $width');
      }
      for (final guide in state.content!.allGuides) {
        await _openGuide(tester, guide.id);
        expect(tester.takeException(), isNull, reason: '${guide.id} at $width');
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('language picker switches the whole app to German', (tester) async {
    final state = await _pumpApp(tester, 'en');
    await tester.tap(find.text('EN').first);
    await tester.pumpAndSettle();
    expect(find.text('Language · Sprache · Idioma'), findsOneWidget);

    await _settleAsync(tester, () async => tester.tap(find.text('Deutsch').last));

    expect(state.lang, 'de');
    expect(find.text('DE'), findsWidgets);
    expect(find.text('Dein Weg durch China'), findsOneWidget);
    expect(find.text('Studium'), findsWidgets);
  });

  testWidgets('language picker offers Spanish and switches to it', (tester) async {
    final state = await _pumpApp(tester, 'en');
    await tester.tap(find.text('EN').first);
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsOneWidget);

    await _settleAsync(tester, () async => tester.tap(find.text('Español')));

    expect(state.lang, 'es');
    expect(find.text('ES'), findsWidgets);
    expect(find.text('Tu camino por China'), findsOneWidget);
    expect(find.text('Viajar a China'), findsOneWidget);
  });

  testWidgets('all languages have the same structure, so progress carries over', (tester) async {
    final state = await _pumpApp(tester, 'en');
    final ids = <String, List<String>>{};
    for (final lang in ['en', 'de', 'es']) {
      await _settleAsync(tester, () => state.setLang(lang));
      ids[lang] = state.content!.allGuides.expand((g) => g.checklistIds).toList();
    }
    expect(ids['de'], ids['en']);
    expect(ids['es'], ids['en']);
  });

  testWidgets('Essential apps: download list, then a searchable app directory', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 6000);
    final apps = state.content!.findGuide('apps')!.guide;
    expect(apps.blocks.map((b) => b.type), ['checklist', 'app_directory']);
    expect(apps.blocks.first.items.map((i) => i['text']).take(3), ['WeChat', 'Alipay', 'Amap']);

    await _openGuide(tester, 'apps');
    expect(find.byType(PageView), findsNothing, reason: 'no sliders, only lists');
    final icons = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName).toList();
    expect(icons, containsAll(['assets/app_icons/wechat.png', 'assets/app_icons/googletranslate.png']));
    expect(find.text('微信'), findsNothing, reason: 'Chinese app names are no longer shown');

    // Search by category or label.
    await tester.enterText(find.widgetWithText(TextField, 'Search apps or categories, e.g. translation'), 'translation');
    await tester.pumpAndSettle();
    expect(find.text('Google Translate'), findsOneWidget);
    expect(find.text('Baidu Translate'), findsOneWidget);
    expect(find.text('Amap (Gaode Maps)'), findsNothing);
    await tester.enterText(find.byType(TextField), 'vpn needed');
    await tester.pumpAndSettle();
    expect(find.text('Google Translate'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    // Filter by category.
    await tester.ensureVisible(find.text('Housing').first); // the filter chip, scrolled into view
    await tester.pumpAndSettle();
    await tester.tap(find.text('Housing').first);
    await tester.pumpAndSettle();
    expect(find.text('Lianjia'), findsOneWidget);
    expect(find.text('Set up in Paying in China'), findsNothing, reason: 'WeChat/Alipay cards are filtered out');
    await tester.ensureVisible(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // WeChat and Alipay link to "Paying in China" instead of repeating the steps.
    expect(find.text('Set up in Paying in China'), findsNWidgets(2));
    await tester.tap(find.text('Set up in Paying in China').first);
    await tester.pumpAndSettle();
    expect(find.text('Explore in detail'), findsOneWidget);
  });

  testWidgets('Getting around: related apps open the app directory filtered to that app', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 4000);
    expect(state.content!.findApp('wechat')!['tags'], contains('cards'));

    await _openGuide(tester, 'getting-around');
    expect(find.text('Related apps'), findsOneWidget);
    await tester.tap(find.text('DiDi'));
    await tester.pumpAndSettle();

    expect(find.text('Essential apps'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'DiDi'), findsOneWidget, reason: 'search is pre-filled');
    expect(find.text('Amap (Gaode Maps)'), findsNothing);
    expect(find.text('GET'), findsOneWidget, reason: 'only the DiDi card is shown');
  });

  testWidgets('saving a step asks to sign in, then shows it in the profile', (tester) async {
    // Tall surface so the whole guide is laid out without scrolling.
    final state = await _pumpApp(tester, 'en', height: 8000);
    await _openGuide(tester, 'entry');

    await tester.tap(find.byTooltip('Save for later').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign in with email'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'lena@example.com');
    await _settleAsync(tester, () async => tester.tap(find.text('Send code')));
    expect(find.text('Check your inbox'), findsOneWidget);

    // Wrong code first, then the demo code shown on screen.
    // Codes can be 6 to 10 digits long (set in Supabase), so longer codes must fit.
    await tester.enterText(find.byType(TextField).last, '12345678');
    expect(find.text('12345678'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '000000');
    await _settleAsync(tester, () async => tester.tap(find.text('Verify')));
    expect(find.text('That code is not correct or has expired.'), findsOneWidget);
    final banner = tester.widget<Text>(find.textContaining('Your code is')).data!;
    final code = RegExp(r'\d{6}').firstMatch(banner)![0]!;
    await tester.enterText(find.byType(TextField).last, code);
    await _settleAsync(tester, () async => tester.tap(find.text('Verify')));

    expect(state.signedIn, isTrue);
    expect(state.saved, contains('step:entry:before-fly:0'));

    // Profile tab lists the saved step.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('lena@example.com'), findsOneWidget);
    expect(find.text('Saved steps'), findsOneWidget);
    expect(find.textContaining('Passport valid for at least 6 months'), findsOneWidget);
  });

  testWidgets('visa search finds a country and its rule', (tester) async {
    await _pumpApp(tester, 'en', height: 3000);
    await _openGuide(tester, 'entry');
    // Before searching: only the most common nationalities, no region boxes.
    expect(find.text('Most common nationalities'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('Slovenia'), findsNothing);
    expect(find.text('Europe'), findsNothing);

    await tester.tap(find.text('Show all 86 countries'));
    await tester.pumpAndSettle();
    expect(find.text('Slovenia'), findsOneWidget);
    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Find your nationality'), 'united st');
    await tester.pumpAndSettle();
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('No visa-free entry · 240h transit only'), findsOneWidget);

    expect(find.byTooltip('Check current rules'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'united st'), 'germ');
    await tester.pumpAndSettle();
    expect(find.text('Visa-free · up to 30 days'), findsOneWidget);
  });

  testWidgets('every guide: checklist first, one "Good to know" card, no loose text blocks', (tester) async {
    final state = await _pumpApp(tester, 'en');
    for (final guide in state.content!.allGuides) {
      final types = guide.blocks.map((b) => b.type).toList();
      expect(types.where((t) => t == 'text' || t == 'tip' || t == 'warning'), isEmpty, reason: guide.id);
      expect(types.where((t) => t == 'info').length, lessThanOrEqualTo(1), reason: guide.id);
      final firstStep = types.indexWhere((t) => t == 'checklist' || t == 'app');
      if (firstStep >= 0) expect(firstStep, 0, reason: '${guide.id}: checklist comes first');
      for (final b in guide.blocks.where((b) => b.hasSteps)) {
        expect(b.id, isNotNull, reason: '${guide.id}: checklists need a stable id');
      }
    }
  });

  testWidgets('visa page: checklist, then search, then one info card with the transit rule', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 3000);
    final entry = state.content!.findGuide('entry')!.guide;
    expect(entry.blocks.map((b) => b.type), ['checklist', 'checklist', 'visa_regions', 'info', 'links']);
    expect(entry.blocks[1].id, 'after-landing', reason: '24-hour registration as a to-do');

    // Every country in every language has an official https source.
    for (final lang in ['en', 'de', 'es']) {
      await _settleAsync(tester, () => state.setLang(lang));
      final regions = state.content!.findGuide('entry')!.guide.blocks.firstWhere((b) => b.type == 'visa_regions');
      for (final r in regions.items) {
        for (final c in r['countries'] as List) {
          expect((c as Map)['source'], startsWith('https://'), reason: '${c['code']} ($lang)');
        }
      }
    }
    await _settleAsync(tester, () => state.setLang('en'));

    await _openGuide(tester, 'entry');
    final checklist = tester.getTopLeft(find.text('Before you fly'));
    final search = tester.getTopLeft(find.widgetWithText(TextField, 'Find your nationality'));
    final official = tester.getTopLeft(find.text('Official rules: National Immigration Administration'));
    final info = tester.getTopLeft(find.text('Good to know'));
    final transit = tester.getTopLeft(find.text('240-hour visa-free transit'));
    expect(checklist.dy, lessThan(search.dy));
    expect(official.dy, greaterThan(search.dy));
    expect(info.dy, greaterThan(official.dy));
    expect(transit.dy, greaterThan(info.dy), reason: 'transit is explained inside the one info card');
    expect(tester.getTopLeft(find.text('After you land')).dy, lessThan(search.dy));
    expect(find.text('Registration within 24 hours'), findsOneWidget);
    // Only Germany, the USA and Spain before searching.
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);
    expect(find.text('United Kingdom'), findsNothing);
  });

  testWidgets('Paying in China links to WeChat and Alipay detail pages', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 4000);
    expect(state.content!.findGuide('payments')!.guide.title, 'Paying in China');

    await _openGuide(tester, 'payments');
    expect(find.text('Explore in detail'), findsOneWidget);
    await tester.tap(find.text('WeChat in detail'));
    await tester.pumpAndSettle();
    expect(find.text('Try it out'), findsOneWidget);
    expect(find.text('Mini programs'), findsOneWidget);
    expect(find.text('Next guide'), findsNothing, reason: 'detail pages are not part of a path');

    // Detail pages are searchable and their steps count like any other.
    expect(state.content!.allGuides.map((g) => g.id), containsAll(['wechat-guide', 'alipay-guide']));
    expect(state.content!.findGuide('alipay-guide')!.guide.checklistIds.first, 'alipay-guide:try-it:0');
  });

  testWidgets('app cards show labels with icons, incl. China App Store only', (tester) async {
    await _pumpApp(tester, 'en', height: 5000);
    await _openGuide(tester, 'daily-life');
    // Lianjia is only in the Chinese App Store; Taobao is in the UK store, so it counts as available.
    expect(find.text('China App Store only'), findsOneWidget);
    expect(find.text('Chinese only'), findsWidgets);
    expect(find.text('Nice to have'), findsWidgets);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await _openGuide(tester, 'apps');
    expect(find.text('Must-have'), findsWidgets);
    expect(find.text('English'), findsWidgets);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });

  testWidgets('GET opens the App Store of the selected language', (tester) async {
    final state = await _pumpApp(tester, 'de');
    Map<String, dynamic> app(String id) {
      for (final g in state.content!.allGuides) {
        for (final b in g.blocks) {
          if (b.app?['id'] == id) return b.app!;
          for (final item in b.items) {
            if (item['id'] == id) return item;
          }
        }
      }
      throw StateError('no app $id');
    }

    expect(appStoreLink(app('alipay'), 'de'), (url: 'https://apps.apple.com/de/app/id333206289', available: true));
    expect(appStoreLink(app('alipay'), 'es'), (url: 'https://apps.apple.com/es/app/id333206289', available: true));
    // English: US or UK store; the link opens the user's own App Store.
    expect(appStoreLink(app('alipay'), 'en'), (url: 'https://apps.apple.com/app/id333206289', available: true));
    expect(appStoreLink(app('taobao'), 'en')!.available, isTrue, reason: 'in the UK store');
    // Only in the Chinese App Store.
    expect(appStoreLink(app('lianjia'), 'de'), (url: 'https://apps.apple.com/cn/app/id405882753', available: false));
    // Meituan: in the US store, not in the German one.
    expect(appStoreLink(app('meituan'), 'en')!.available, isTrue);
    expect(appStoreLink(app('meituan'), 'de')!.available, isFalse);
  });

  test('ticks from older versions move to the "Before you fly" checklist, once', () async {
    SharedPreferences.setMockInitialValues({
      'checked': ['entry:3:0', 'entry:3:4', 'apps:1:0'],
      'saved:lena@example.com': ['step:entry:3:2', 'guide:entry'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, DemoAuthService(prefs));
    expect(state.checked, {'entry:before-fly:0', 'entry:before-fly:4', 'apps:1:0'});
    expect(prefs.getStringList('saved:lena@example.com'), ['step:entry:before-fly:2', 'guide:entry']);

    // Every reordered checklist keeps its ticks.
    expect(AppState.migratedKey('checked', 'payments:1:2'), 'payments:alipay:2');
    expect(AppState.migratedKey('saved', 'step:campus-life:2:0'), 'step:campus-life:settle-in:0');
    expect(AppState.migratedKey('checked', 'payments:alipay:2'), isNull);
    // "Essential apps" now has one download list; WeChat/Alipay steps moved to "Paying in China".
    expect(AppState.migratedKey('checked', 'apps:8:0'), 'apps:downloads:2'); // Amap, from the oldest layout
    expect(AppState.migratedKey('checked', 'apps:install:3'), 'apps:downloads:5');
    expect(AppState.migratedKey('checked', 'apps:wechat:0'), 'apps:downloads:0');
    expect(AppState.migratedKey('saved', 'step:apps:alipay:1'), 'step:payments:alipay:2');
    expect(AppState.migratedKey('checked', 'apps:downloads:2'), isNull);
    // "Internet & VPN": offline maps removed, the last step moved up.
    expect(AppState.migratedKey('checked', 'internet:get-connected:3'), 'internet:connect:2');
    expect(AppState.migratedKey('checked', 'internet:4:3'), 'internet:connect:2'); // oldest layout
    expect(AppState.migratedKey('checked', 'internet:connect:2'), isNull);

    // A later launch must not move anything again.
    state.toggle('entry:3:1', true);
    AppState(prefs, DemoAuthService(prefs));
    expect(prefs.getStringList('checked'), contains('entry:3:1'));
  });
}
