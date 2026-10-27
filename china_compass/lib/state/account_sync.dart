import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/sync_store.dart';

enum SyncStatus { localOnly, syncing, synced, pending }

/// Progress of one signed-in user. Every change is written to a local copy right
/// away (fast, works offline) and pushed to the [SyncStore] in the background.
/// Changes that fail to upload stay marked as dirty and are retried.
class AccountSync {
  AccountSync({
    required this.prefs,
    required this.store,
    required this.userId,
    required this.onChanged,
    this.migrateKey,
    this.retryInterval = const Duration(seconds: 20),
  }) {
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      for (final j in jsonDecode(raw) as List) {
        final item = SyncItem.fromJson(j as Map<String, dynamic>);
        _items[item.id] = item;
      }
    }
    _applyMigrations();
  }

  /// Renames keys of older app versions (see [migrateKey]); the new key is uploaded
  /// and the old one marked as removed, so other devices follow along.
  void _applyMigrations() {
    final migrate = migrateKey;
    if (migrate == null) return;
    for (final item in [..._items.values]) {
      if (item.deleted) continue;
      final newKey = migrate(item.kind, item.key);
      if (newKey == null) continue;
      final existing = _items['${item.kind}|$newKey'];
      if (existing == null || existing.updatedAt.isBefore(item.updatedAt)) {
        _items['${item.kind}|$newKey'] = SyncItem(
          kind: item.kind,
          key: newKey,
          value: item.value,
          updatedAt: item.updatedAt,
          dirty: true,
        );
      }
      _items[item.id] = SyncItem(kind: item.kind, key: item.key, deleted: true, updatedAt: DateTime.now().toUtc(), dirty: true);
    }
  }

  final SharedPreferences prefs;
  final SyncStore store;
  final String userId;
  final void Function() onChanged;

  /// Maps an old key to its new name (or null to keep it), for content changes.
  final String? Function(String kind, String key)? migrateKey;
  final Duration retryInterval;

  final _items = <String, SyncItem>{};
  bool _syncing = false;
  bool _syncAgain = false;
  bool _disposed = false;
  Timer? _debounce;
  Timer? _retry;

  String get _cacheKey => 'items:$userId';

  /// Keys of a kind that are currently set (not removed).
  Set<String> keys(String kind) =>
      {for (final i in _items.values) if (i.kind == kind && !i.deleted) i.key};

  String? setting(String key) {
    final i = _items['setting|$key'];
    return i == null || i.deleted ? null : i.value;
  }

  bool get hasPending => _items.values.any((i) => i.dirty);

  SyncStatus get status => !store.isRemote
      ? SyncStatus.localOnly
      : _syncing
          ? SyncStatus.syncing
          : hasPending
              ? SyncStatus.pending
              : SyncStatus.synced;

  /// Records a change locally and schedules an upload.
  void set(String kind, String key, {bool deleted = false, String? value, DateTime? at}) {
    final item = SyncItem(
      kind: kind,
      key: key,
      value: value,
      deleted: deleted,
      updatedAt: (at ?? DateTime.now()).toUtc(),
      dirty: true,
    );
    _items[item.id] = item;
    _save();
    onChanged();
    _scheduleSync(const Duration(milliseconds: 800));
  }

  /// Pulls from the server, merges (newest wins) and pushes local changes.
  Future<void> sync() async {
    if (_disposed) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    if (!store.isRemote) {
      // Nothing to upload to: local changes are final.
      for (final id in [for (final i in _items.values) if (i.dirty) i.id]) {
        _items[id] = _items[id]!.copyWith(dirty: false);
      }
      _save();
      return;
    }
    _syncing = true;
    onChanged();
    try {
      for (final remote in await store.fetchAll(userId)) {
        final local = _items[remote.id];
        if (local == null || !local.updatedAt.isAfter(remote.updatedAt)) {
          _items[remote.id] = remote.copyWith(dirty: false);
        }
      }
      _applyMigrations();
      final toPush = [for (final i in _items.values) if (i.dirty) i];
      await store.upsert(userId, toPush);
      for (final pushed in toPush) {
        // Only clear the flag if nothing changed the item while uploading.
        if (identical(_items[pushed.id], pushed)) _items[pushed.id] = pushed.copyWith(dirty: false);
      }
      _retry?.cancel();
      _retry = null;
    } catch (_) {
      // Offline or server error: keep the changes and try again later.
      _retry ??= Timer.periodic(retryInterval, (_) => sync());
    } finally {
      _syncing = false;
      _save();
      if (!_disposed) onChanged();
    }
    if (_syncAgain && !_disposed) {
      _syncAgain = false;
      await sync();
    }
  }

  void _scheduleSync(Duration delay) {
    if (!store.isRemote) {
      sync();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(delay, sync);
  }

  void _save() {
    if (_disposed) return;
    prefs.setString(_cacheKey, jsonEncode([for (final i in _items.values) i.toJson()]));
  }

  /// Removes this user's data from the device (sign-out, account deletion).
  Future<void> clearDevice() async {
    dispose();
    await prefs.remove(_cacheKey);
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
  }
}
