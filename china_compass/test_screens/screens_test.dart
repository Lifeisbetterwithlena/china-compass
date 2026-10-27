// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders key screens to PNGs for a visual check (not part of the normal test run):
//   flutter test test_screens --update-goldens
import 'dart:io';

import 'package:china_compass/main.dart';
import 'package:china_compass/screens/guide_screen.dart';
import 'package:china_compass/screens/login_screen.dart';
import 'package:china_compass/services/auth_service.dart';
import 'package:china_compass/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  // The app's own font from assets, plus Material icons from the Flutter SDK.
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final dir = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')
        ..addFont(File('$dir/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView)))
      .load();
}

Future<AppState> _app(WidgetTester tester, {String lang = 'en', double height = 844, Map<String, Object> prefs = const {}}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(390 * 2, height * 2);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'lang': lang, ...prefs});
  late AppState state;
  await tester.runAsync(() async {
    final p = await SharedPreferences.getInstance();
    state = AppState(p, DemoAuthService(p));
    await state.load();
  });
  await tester.pumpWidget(AppScope(state: state, child: const ChinaCompassApp()));
  // Decode the bundled app icon images.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
  return state;
}

Future<void> _push(WidgetTester tester, Widget page) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute(builder: (_) => page));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

void main() {
  setUpAll(_loadFonts);

  testWidgets('home', (t) async {
    await _app(t, height: 1250);
    await _shot('1_home');
  });

  testWidgets('desktop home', (t) async {
    await _app(t);
    t.view.physicalSize = const Size(1440 * 2, 1000 * 2);
    await t.pumpAndSettle();
    await _shot('d1_home');
  });

  testWidgets('desktop path and guide', (t) async {
    await _app(t);
    t.view.physicalSize = const Size(1440 * 2, 1000 * 2);
    await t.pumpAndSettle();
    await t.tap(find.text('Travel').last);
    await t.pumpAndSettle();
    await _shot('d2_travel');
    await _push(t, const GuideScreen(guideId: 'entry'));
    await _shot('d3_guide');
  });

  testWidgets('home in Spanish', (t) async {
    await _app(t, lang: 'es', height: 1250);
    await _shot('7_home_es');
  });

  testWidgets('language picker', (t) async {
    await _app(t, lang: 'es');
    await t.tap(find.text('ES').first);
    await t.pumpAndSettle();
    await _shot('8_language_picker');
  });

  testWidgets('visa page in Spanish', (t) async {
    await _app(t, lang: 'es', height: 1700);
    await _push(t, const GuideScreen(guideId: 'entry'));
    await _shot('9_visa_es');
  });

  testWidgets('daily life in German', (t) async {
    await _app(t, lang: 'de', height: 2000);
    await _push(t, const GuideScreen(guideId: 'daily-life'));
    await _shot('10_daily_life_de');
  });

  for (final id in ['getting-around']) {
    testWidgets('guide $id', (t) async {
      await _app(t, height: 2600);
      await _push(t, GuideScreen(guideId: id));
      await _shot('guide_$id');
    });
  }

  testWidgets('apps in German', (t) async {
    await _app(t, lang: 'de', height: 2400);
    await _push(t, const GuideScreen(guideId: 'payments'));
    await _shot('de_payments');
  });

  testWidgets('travel path', (t) async {
    await _app(t, height: 1300);
    await t.tap(find.text('Travel').last);
    await t.pumpAndSettle();
    await _shot('1b_travel');
  });

  testWidgets('visa', (t) async {
    await _app(t, height: 1900);
    await _push(t, const GuideScreen(guideId: 'entry'));
    await _shot('2_visa');
  });

  testWidgets('apps', (t) async {
    await _app(t, height: 2600);
    await _push(t, const GuideScreen(guideId: 'apps'));
    await _shot('3_apps');
  });

  testWidgets('payments', (t) async {
    await _app(t, height: 1500);
    await _push(t, const GuideScreen(guideId: 'payments'));
    await _shot('4_payments');
  });

  testWidgets('login', (t) async {
    await _app(t);
    await _push(t, const LoginScreen());
    await _shot('5_login');
  });

  testWidgets('profile', (t) async {
    await _app(t, lang: 'de', height: 1100, prefs: {
      'demo_email': 'lena@example.com',
      'saved:lena@example.com': ['step:entry:before-fly:0', 'step:entry:before-fly:5', 'step:payments:1:1', 'guide:scholarships'],
      'checked': ['entry:before-fly:0'],
    });
    await t.tap(find.text('Profil').last);
    await t.pumpAndSettle();
    await _shot('6_profile_de');
  });
}
