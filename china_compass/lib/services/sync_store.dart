import 'package:supabase_flutter/supabase_flutter.dart';

/// One piece of user progress: a ticked step, a saved step or guide, or a setting.
/// Removals are kept as `deleted` so other devices learn about them; the newest
/// `updatedAt` wins when devices disagree.
class SyncItem {
  SyncItem({
    required this.kind,
    required this.key,
    this.value,
    this.deleted = false,
    required this.updatedAt,
    this.dirty = false,
  });

  final String kind; // checked | saved | setting
  final String key;
  final String? value;
  final bool deleted;
  final DateTime updatedAt;

  /// Changed on this device and not yet confirmed by the server.
  final bool dirty;

  String get id => '$kind|$key';

  SyncItem copyWith({bool? dirty}) =>
      SyncItem(kind: kind, key: key, value: value, deleted: deleted, updatedAt: updatedAt, dirty: dirty ?? this.dirty);

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'key': key,
        'value': value,
        'deleted': deleted,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        if (dirty) 'dirty': true,
      };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
        kind: json['kind'] as String,
        key: json['key'] as String,
        value: json['value'] as String?,
        deleted: json['deleted'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        dirty: json['dirty'] as bool? ?? false,
      );
}

/// Where a signed-in user's progress lives besides the device.
abstract class SyncStore {
  /// False for stores that keep everything on the device only (demo mode).
  bool get isRemote;

  Future<List<SyncItem>> fetchAll(String userId);
  Future<void> upsert(String userId, List<SyncItem> items);
  Future<void> deleteAccount();
}

/// Demo mode: nothing leaves the device.
class LocalOnlySyncStore implements SyncStore {
  @override
  bool get isRemote => false;

  @override
  Future<List<SyncItem>> fetchAll(String userId) async => const [];

  @override
  Future<void> upsert(String userId, List<SyncItem> items) async {}

  @override
  Future<void> deleteAccount() async {}
}

/// The `user_items` table in Supabase (see supabase/migrations).
class SupabaseSyncStore implements SyncStore {
  SupabaseSyncStore(this._client);

  final SupabaseClient _client;

  @override
  bool get isRemote => true;

  @override
  Future<List<SyncItem>> fetchAll(String userId) async {
    final rows = await _client.from('user_items').select('kind, key, value, deleted, updated_at').eq('user_id', userId);
    return [for (final r in rows) SyncItem.fromJson(r)];
  }

  @override
  Future<void> upsert(String userId, List<SyncItem> items) async {
    if (items.isEmpty) return;
    await _client.from('user_items').upsert(
      [for (final i in items) {...i.copyWith(dirty: false).toJson(), 'user_id': userId}],
      onConflict: 'user_id,kind,key',
    );
  }

  @override
  Future<void> deleteAccount() => _client.rpc('delete_my_account');
}
