import 'package:china_compass/services/auth_service.dart';
import 'package:china_compass/services/sync_store.dart';
import 'package:china_compass/state/account_sync.dart';
import 'package:china_compass/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the Supabase `user_items` table.
class FakeServer implements SyncStore {
  final rows = <String, Map<String, SyncItem>>{}; // userId -> id -> item
  bool online = true;
  bool accountDeleted = false;

  @override
  bool get isRemote => true;

  @override
  Future<List<SyncItem>> fetchAll(String userId) async {
    if (!online) throw Exception('offline');
    return [...?rows[userId]?.values];
  }

  @override
  Future<void> upsert(String userId, List<SyncItem> items) async {
    if (!online) throw Exception('offline');
    final table = rows.putIfAbsent(userId, () => {});
    for (final i in items) {
      table[i.id] = i.copyWith(dirty: false);
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (!online) throw Exception('offline');
    accountDeleted = true;
    rows.clear();
  }
}

const email = 'lena@example.com';
const userId = 'demo:$email';

/// A fresh phone: empty storage, optionally already signed in.
Future<AppState> device(FakeServer server, {Map<String, Object> prefs = const {}, bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({'lang': 'en', if (signedIn) 'demo_email': email, ...prefs});
  final p = await SharedPreferences.getInstance();
  final state = AppState(p, DemoAuthService(p), store: server);
  await state.load();
  await settle();
  return state;
}

/// Waits for the background upload (debounced by 800 ms).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 1100));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a tick on one phone shows up on another phone', () async {
    final server = FakeServer();
    final phoneA = await device(server);
    phoneA.toggle('safety:prepare:1', true);
    phoneA.toggleSaved('guide:scholarships');
    await settle();
    expect(phoneA.syncStatus, SyncStatus.synced);
    phoneA.dispose();

    final phoneB = await device(server);
    expect(phoneB.checked, contains('safety:prepare:1'));
    expect(phoneB.saved, contains('guide:scholarships'));
    phoneB.dispose();
  });

  test('changes made offline are kept and uploaded once back online', () async {
    final server = FakeServer();
    final phone = await device(server);
    server.online = false;
    phone.toggle('payments:alipay:0', true);
    await settle();
    expect(phone.checked, contains('payments:alipay:0'), reason: 'works offline');
    expect(phone.syncStatus, SyncStatus.pending);
    expect(server.rows[userId]?['checked|payments:alipay:0'], isNull);

    server.online = true;
    await phone.syncNow();
    expect(phone.syncStatus, SyncStatus.synced);
    expect(server.rows[userId]!['checked|payments:alipay:0']!.deleted, isFalse);
    phone.dispose();
  });

  test('ticks made before signing in move into the account', () async {
    final server = FakeServer();
    final phone = await device(server, signedIn: false, prefs: {
      'checked': ['internet:connect:0', 'internet:connect:1'],
    });
    expect(phone.checked, {'internet:connect:0', 'internet:connect:1'});

    final code = await phone.auth.sendCode(email);
    await phone.auth.verify(email, code!);
    await settle();

    expect(phone.signedIn, isTrue);
    expect(phone.checked, containsAll(['internet:connect:0', 'internet:connect:1']));
    expect(server.rows[userId]!.keys, containsAll(['checked|internet:connect:0', 'checked|internet:connect:1']));
    phone.dispose();
  });

  test('unticking on one phone removes the tick on the other (newest change wins)', () async {
    final server = FakeServer();
    final phoneA = await device(server);
    phoneA.toggle('apply:documents:0', true);
    await settle();
    phoneA.toggle('apply:documents:0', false);
    await settle();
    phoneA.dispose();

    final phoneB = await device(server);
    expect(phoneB.checked, isNot(contains('apply:documents:0')));
    phoneB.dispose();
  });

  test('sign-out clears the device; signing in again restores everything', () async {
    final server = FakeServer();
    final phone = await device(server);
    phone.toggle('safety:prepare:0', true);
    await settle();
    await phone.signOut();

    expect(phone.signedIn, isFalse);
    expect(phone.checked, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('items:')), isEmpty);
    phone.dispose();

    final again = await device(server);
    expect(again.checked, contains('safety:prepare:0'));
    again.dispose();
  });

  test('the language follows the account to a new phone', () async {
    final server = FakeServer();
    final phoneA = await device(server);
    await phoneA.setLang('de');
    await settle();
    phoneA.dispose();

    final phoneB = await device(server);
    expect(phoneB.lang, 'de');
    phoneB.dispose();
  });

  test('ticks saved by an older app version are renamed in the account', () async {
    final server = FakeServer();
    final old = DateTime.utc(2026, 10, 1);
    server.rows[userId] = {
      'checked|entry:2:0': SyncItem(kind: 'checked', key: 'entry:2:0', updatedAt: old),
      'saved|step:entry:2:3': SyncItem(kind: 'saved', key: 'step:entry:2:3', updatedAt: old),
    };
    final phone = await device(server);
    expect(phone.checked, contains('entry:before-fly:0'));
    expect(phone.checked, isNot(contains('entry:2:0')));
    expect(phone.saved, contains('step:entry:before-fly:3'));
    await settle();
    expect(server.rows[userId]!['checked|entry:before-fly:0']!.deleted, isFalse);
    expect(server.rows[userId]!['checked|entry:2:0']!.deleted, isTrue, reason: 'other phones learn about the rename');
    phone.dispose();
  });

  test('delete account removes server data and signs out', () async {
    final server = FakeServer();
    final phone = await device(server);
    phone.toggle('entry:before-fly:1', true);
    await settle();
    await phone.deleteAccount();

    expect(server.accountDeleted, isTrue);
    expect(server.rows, isEmpty);
    expect(phone.signedIn, isFalse);
    expect(phone.checked, isEmpty);
    phone.dispose();
  });
}
