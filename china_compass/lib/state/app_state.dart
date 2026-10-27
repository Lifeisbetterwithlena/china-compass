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
    if (saved != null && appLanguages.any((l) => l.code == saved)) return saved;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return appLanguages.any((l) => l.code == device) ? device : 'en';
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
      final account = AccountSync(prefs: _prefs, store: store, userId: userId, onChanged: notifyListeners);
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
    if (code != null && appLanguages.any((l) => l.code == code)) {
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
