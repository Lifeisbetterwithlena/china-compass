import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/strings.dart';
import 'screens/home_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/sync_store.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/floating_nav.dart';
import 'widgets/layout.dart';
import 'widgets/side_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  AuthService auth;
  SyncStore store;
  if (supabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    auth = SupabaseAuthService(Supabase.instance.client);
    store = SupabaseSyncStore(Supabase.instance.client);
  } else {
    auth = DemoAuthService(prefs);
    store = LocalOnlySyncStore();
  }

  final state = AppState(prefs, auth, store: store);
  await state.load();
  runApp(AppScope(state: state, child: const ChinaCompassApp()));
}

class ChinaCompassApp extends StatelessWidget {
  const ChinaCompassApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: 'China Compass',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: languageFor(state.lang).locale,
      supportedLocales: [for (final l in appLanguages) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Let sliders be dragged with a mouse or trackpad too (web and desktop).
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      home: state.content == null
          ? Scaffold(body: Center(child: Text(state.t('loadError'))))
          : const Shell(),
    );
  }
}

/// Bottom navigation with five tabs: Home, Travel, Study, Life, Profile.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the app: fetch changes from other devices and upload pending ones.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) AppScope.of(context).syncNow();
  }

  static const _personaTabs = ['travel', 'study', 'life'];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = [
      FloatingNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: state.t('tabHome')),
      FloatingNavItem(icon: Icons.flight_outlined, activeIcon: Icons.flight_rounded, label: state.t('tabTravel')),
      FloatingNavItem(icon: Icons.school_outlined, activeIcon: Icons.school_rounded, label: state.t('tabStudy')),
      FloatingNavItem(
          icon: Icons.temple_buddhist_outlined, activeIcon: Icons.temple_buddhist_rounded, label: state.t('tabLife')),
      FloatingNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: state.t('tabProfile')),
    ];
    void select(int i) => setState(() => _tab = i);
    final pages = IndexedStack(
      index: _tab,
      children: [
        HomeScreen(onOpenPersona: (id) => select(_personaTabs.indexOf(id) + 1)),
        for (final id in _personaTabs) PersonaScreen(personaId: id),
        const ProfileScreen(),
      ],
    );

    // Wide windows (tablet, desktop): navigation on the left.
    if (isWideWindow(context)) {
      return Scaffold(
        body: Row(
          children: [
            SideNav(items: items, index: _tab, onTap: select),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true, // content scrolls behind the floating tab bar
      body: pages,
      bottomNavigationBar: FloatingNavBar(index: _tab, onTap: select, items: items),
    );
  }
}
