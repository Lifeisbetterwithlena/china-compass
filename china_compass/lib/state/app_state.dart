import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/content.dart';
import '../services/auth_service.dart';
import '../services/sync_store.dart';
import 'account_sync.dart';

/// Holds the selected language, the loaded content and the user's progress.
///
/// Signed out, ticked steps live on the device ("guest" progress). On sign-in
/// they move into the account, and from then on all progress (ticks, saved
/// steps and guides, language) belongs to the account and syncs via [AccountSync].
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.auth, {SyncStore? store})
      : store = store ?? LocalOnlySyncStore(),
        lang = _initialLang(_prefs) {
    _migrate(_prefs);
    _migrateKeys(_prefs);
    _guestChecked.addAll(_prefs.getStringList(_checkedKey) ?? []);
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  /// One-time fixes for progress stored by position when a guide's blocks move.
  static void _migrate(SharedPreferences prefs) {
    // v2: the separate transit text in "entry" was removed, so "Before you fly" moved from block 3 to 2.
    const flag = 'migrated_entry_v2';
    if (prefs.getBool(flag) ?? false) return;
    String move(String key, String prefix) =>
        key.startsWith('${prefix}entry:3:') ? '${prefix}entry:2:${key.substring('${prefix}entry:3:'.length)}' : key;
    final checked = prefs.getStringList(_checkedKey);
    if (checked != null) prefs.setStringList(_checkedKey, [for (final k in checked) move(k, '')]);
    for (final key in prefs.getKeys().where((k) => k.startsWith('saved:'))) {
      prefs.setStringList(key, [for (final k in prefs.getStringList(key) ?? const <String>[]) move(k, 'step:')]);
    }
    prefs.setBool(flag, true);
  }

  /// Checklists used to be identified by their position in the guide. They now have
  /// stable ids; old position-based keys (`guide:index:item`) are renamed once, on the
  /// device and in the account. Keys: old `guide:index` → new `guide:id`.
  static const _movedChecklists = {
    'entry:2': 'entry:before-fly',
    'internet:4': 'internet:get-connected',
    'payments:1': 'payments:alipay',
    'payments:2': 'payments:wechat-pay',
    'apps:2': 'apps:wechat',
    'apps:3': 'apps:alipay',
    'apps:8': 'apps:install',
    'safety:3': 'safety:prepare',
    'programs:3': 'programs:research',
    'scholarships:4': 'scholarships:funding',
    'apply:1': 'apply:documents',
    'student-visa:2': 'student-visa:x-visa',
    'residence-permit:1': 'residence-permit:first-30-days',
    'campus-life:2': 'campus-life:settle-in',
  };

  /// Single steps that moved to another checklist (applied after [_movedChecklists]).
  /// "Essential apps" now has one download list; its WeChat/Alipay set-up steps
  /// live in "Paying in China".
  static const _movedSteps = {
    'apps:install:0': 'apps:downloads:2', // Amap
    'apps:install:1': 'apps:downloads:3', // DiDi
    'apps:install:2': 'apps:downloads:4', // Trip.com or 12306
    'apps:install:3': 'apps:downloads:5', // translation app
    'apps:wechat:0': 'apps:downloads:0', // install WeChat
    'apps:wechat:1': 'payments:wechat-pay:2', // get verified
    'apps:alipay:0': 'apps:downloads:1', // install Alipay
    'apps:alipay:1': 'payments:alipay:2', // link your card
  };

  /// New name for a ticked (`checked`) or saved (`saved`, `step:` prefix) key, or null.
  static String? migratedKey(String kind, String key) {
    final prefix = kind == 'saved' ? 'step:' : '';
    if ((kind != 'checked' && kind != 'saved') || !key.startsWith(prefix)) return null;
    var step = key.substring(prefix.length);
    final parts = step.split(':');
    if (parts.length != 3) return null;
    final moved = _movedChecklists['${parts[0]}:${parts[1]}'];
    if (moved != null) step = '$moved:${parts[2]}';
    step = _movedSteps[step] ?? step;
    return step == key.substring(prefix.length) ? null : '$prefix$step';
  }

  static void _migrateKeys(SharedPreferences prefs) {
    const flag = 'migrated_checklist_ids_v5';
    if (prefs.getBool(flag) ?? false) return;
    final checked = prefs.getStringList(_checkedKey);
    if (checked != null) {
      prefs.setStringList(_checkedKey, [for (final k in checked) migratedKey('checked', k) ?? k]);
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith('saved:'))) {
      prefs.setStringList(
          key, [for (final k in prefs.getStringList(key) ?? const <String>[]) migratedKey('saved', k) ?? k]);
    }
    prefs.setBool(flag, true);
  }

  static const _langKey = 'lang';
  static const _checkedKey = 'checked';

  final SharedPreferences _prefs;
  final AuthService auth;
  final SyncStore store;
  final _cache = <String, Content>{};
  final _guestChecked = <String>{};
  AccountSync? _account;

  String lang;
  Content? content;
  Object? loadError;

  /// First launch follows the device language; after that the user's choice wins.
  static String _initialLang(SharedPreferences prefs) {
    final saved = prefs.getString(_langKey);
    if (saved != null && isEnabledLanguage(saved)) return saved;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return isEnabledLanguage(device) ? device : 'en';
  }

  String t(String key, [Map<String, Object> vars = const {}]) => tr(lang, key, vars);

  Future<void> load() => _loadContent(lang);

  Future<void> setLang(String code, {bool remember = true}) async {
    if (code == lang) return;
    await _loadContent(code);
    lang = code;
    await _prefs.setString(_langKey, code);
    if (remember) _account?.set('setting', 'lang', value: code);
    notifyListeners();
  }

  Future<void> _loadContent(String code) async {
    try {
      content = _cache[code] ??= Content.fromJson(
        jsonDecode(await rootBundle.loadString('assets/content/content.$code.json')) as Map<String, dynamic>,
      );
      loadError = null;
    } catch (e) {
      loadError = e;
    }
    notifyListeners();
  }

  // ---------- Account ----------

  bool get signedIn => _account != null;

  /// Sync state for the profile screen; null when signed out.
  SyncStatus? get syncStatus => _account?.status;

  void _onAuthChanged() {
    final userId = auth.userId;
    if (userId == _account?.userId) {
      notifyListeners();
      return;
    }
    _account?.dispose();
    _account = null;
    if (userId != null) {
      final account = AccountSync(
        prefs: _prefs,
        store: store,
        userId: userId,
        onChanged: notifyListeners,
        migrateKey: migratedKey,
      );
      _account = account;
      _importDeviceProgress(account);
      unawaited(account.sync().then((_) => _applyAccountLanguage(account)));
    }
    notifyListeners();
  }

  /// Moves progress made on this device before signing in into the account,
  /// so nothing is lost.
  void _importDeviceProgress(AccountSync account) {
    for (final id in _guestChecked) {
      account.set('checked', id);
    }
    _guestChecked.clear();
    _prefs.remove(_checkedKey);

    // Earlier versions kept saved items per email on the device only.
    final legacyKey = 'saved:${auth.email}';
    for (final key in _prefs.getStringList(legacyKey) ?? const <String>[]) {
      account.set('saved', key);
    }
    _prefs.remove(legacyKey);
  }

  Future<void> _applyAccountLanguage(AccountSync account) async {
    final code = account.setting('lang');
    if (_account != account) return;
    if (code != null && isEnabledLanguage(code)) {
      await setLang(code, remember: false);
    } else {
      account.set('setting', 'lang', value: lang);
    }
  }

  /// Uploads pending changes if possible, then removes this account's data from the device.
  Future<void> signOut() async {
    final account = _account;
    if (account != null) {
      if (account.hasPending) {
        await account.sync().timeout(const Duration(seconds: 8), onTimeout: () {});
      }
      await account.clearDevice();
      _account = null;
    }
    await auth.signOut();
    notifyListeners();
  }

  /// Syncs right away (e.g. when the app comes back to the foreground).
  Future<void> syncNow() async => _account?.sync();

  /// Deletes the account and all its progress on the server and on this device.
  Future<void> deleteAccount() async {
    await store.deleteAccount();
    await _account?.clearDevice();
    _account = null;
    await auth.signOut();
    notifyListeners();
  }

  // ---------- Checklist progress ----------

  /// Ticked steps of the account, or of this device when signed out.
  Set<String> get checked => _account?.keys('checked') ?? _guestChecked;

  void toggle(String id, bool value) {
    final account = _account;
    if (account != null) {
      account.set('checked', id, deleted: !value);
    } else {
      value ? _guestChecked.add(id) : _guestChecked.remove(id);
      _prefs.setStringList(_checkedKey, _guestChecked.toList());
    }
    notifyListeners();
  }

  ({int done, int total}) progress(Iterable<Guide> guides) {
    final done = checked;
    final ids = guides.expand((g) => g.checklistIds).toList();
    return (done: ids.where(done.contains).length, total: ids.length);
  }

  // ---------- Saved for later ----------

  /// Saved items of the signed-in user: `step:guide:block:item` or `guide:id`.
  Set<String> get saved => _account?.keys('saved') ?? const {};

  bool isSaved(String key) => saved.contains(key);

  /// Only call when signed in; the UI asks the user to sign in first.
  void toggleSaved(String key) {
    _account?.set('saved', key, deleted: isSaved(key));
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    _account?.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
