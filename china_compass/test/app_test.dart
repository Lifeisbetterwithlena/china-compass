import 'package:china_compass/main.dart';
import 'package:china_compass/screens/guide_screen.dart';
import 'package:china_compass/services/auth_service.dart';
import 'package:china_compass/state/app_state.dart';
import 'package:china_compass/widgets/app_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpApp(WidgetTester tester, String lang, {double height = 812}) async {
  await tester.binding.setSurfaceSize(Size(375, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

  testWidgets('WeChat and Alipay are single sections with their own steps, other apps in sliders', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 5000);
    final apps = state.content!.findGuide('apps')!.guide;
    expect(apps.blocks.where((b) => b.type == 'app').map((b) => b.app!['id']), ['wechat', 'alipay']);
    final sliders = apps.blocks.where((b) => b.type == 'apps' && b.items.length > 2).length;

    await _openGuide(tester, 'apps');
    expect(find.byType(PageView), findsNWidgets(sliders), reason: 'only categories with 3+ apps slide');
    final icons = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName).toList();
    expect(icons, containsAll(['assets/app_icons/wechat.png', 'assets/app_icons/amap.png']));
    expect(find.text('微信'), findsNothing, reason: 'Chinese app names are no longer shown');
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
    await _settleAsync(tester, () async => tester.enterText(find.byType(TextField).last, '000000'));
    expect(find.text('That code is not correct or has expired.'), findsOneWidget);
    final banner = tester.widget<Text>(find.textContaining('Your code is')).data!;
    final code = RegExp(r'\d{6}').firstMatch(banner)![0]!;
    await _settleAsync(tester, () async => tester.enterText(find.byType(TextField).last, code));

    expect(state.signedIn, isTrue);
    final checklistIndex = state.content!.findGuide('entry')!.guide.blocks.indexWhere((b) => b.hasSteps);
    expect(state.saved, contains('step:entry:$checklistIndex:0'));

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
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text('North & South America'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Find your nationality'), 'united st');
    await tester.pumpAndSettle();
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('No visa-free entry · 240h transit only'), findsOneWidget);

    expect(find.text('Check current rules'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'united st'), 'germ');
    await tester.pumpAndSettle();
    expect(find.text('Visa-free · up to 30 days'), findsOneWidget);
  });

  testWidgets('visa page: transit note above the search, official source below it', (tester) async {
    final state = await _pumpApp(tester, 'en', height: 3000);
    final entry = state.content!.findGuide('entry')!.guide;
    expect(entry.blocks.map((b) => b.type), ['text', 'visa_regions', 'checklist', 'tip', 'links'],
        reason: 'the separate 240-hour transit section is gone');

    // Every country in every language has an official https source.
    for (final lang in ['en', 'de', 'es']) {
      await _settleAsync(tester, () => state.setLang(lang));
      final regions = state.content!.findGuide('entry')!.guide.blocks[1];
      for (final r in regions.items) {
        for (final c in r['countries'] as List) {
          expect((c as Map)['source'], startsWith('https://'), reason: '${c['code']} ($lang)');
        }
      }
    }
    await _settleAsync(tester, () => state.setLang('en'));

    await _openGuide(tester, 'entry');
    final intro = tester.getTopLeft(find.textContaining('No visa-free entry for your country?'));
    final search = tester.getTopLeft(find.widgetWithText(TextField, 'Find your nationality'));
    final official = tester.getTopLeft(find.text('Official rules: National Immigration Administration'));
    expect(intro.dy, lessThan(search.dy));
    expect(official.dy, greaterThan(search.dy));
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
    expect(appStoreLink(app('alipay'), 'en'), (url: 'https://apps.apple.com/us/app/id333206289', available: true));
    // Only in the Chinese App Store.
    expect(appStoreLink(app('lianjia'), 'de'), (url: 'https://apps.apple.com/cn/app/id405882753', available: false));
    // Meituan: in the US store, not in the German one.
    expect(appStoreLink(app('meituan'), 'en')!.available, isTrue);
    expect(appStoreLink(app('meituan'), 'de')!.available, isFalse);
  });

  test('checklist progress moves with the "Before you fly" checklist, once', () async {
    SharedPreferences.setMockInitialValues({
      'checked': ['entry:3:0', 'entry:3:4', 'apps:1:0'],
      'saved:lena@example.com': ['step:entry:3:2', 'guide:entry'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, DemoAuthService(prefs));
    expect(state.checked, {'entry:2:0', 'entry:2:4', 'apps:1:0'});
    expect(prefs.getStringList('saved:lena@example.com'), ['step:entry:2:2', 'guide:entry']);

    // A later launch must not move anything again.
    state.toggle('entry:3:1', true);
    AppState(prefs, DemoAuthService(prefs));
    expect(prefs.getStringList('checked'), contains('entry:3:1'));
  });
}
