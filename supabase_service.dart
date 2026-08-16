import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import 'database_service.dart';
import 'team_service.dart';

/// Everything here is best-effort: if there's no connection, every method
/// fails quietly and the app keeps running off local data. Nothing in the
/// UI should ever `await` these calls before rendering.
///
/// Each device signs in as an anonymous Supabase Auth user (free, no SMS
/// cost) the first time it successfully reaches the internet, then
/// resolves which organization (business) it belongs to via
/// TeamService — either its own (first device, becomes owner) or one it
/// joined with an invite code. See supabase/migration_phase7_roles.sql
/// for the full access-control model.
class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  static const _cacheKey = 'cached_subscription_status';

  SupabaseClient get _client => Supabase.instance.client;

  /// Call once in main() before runApp(). Reads keys from --dart-define
  /// so they aren't hardcoded into source control. If no keys are passed
  /// (Phase 1/2 default), this is a no-op — the app just runs fully
  /// offline, and every method below already fails quietly without a
  /// live client.
  static Future<void> init() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || anonKey.isEmpty) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  Future<void> _ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    // Requires "Allow anonymous sign-ins" enabled in Dashboard →
    // Authentication → Settings (see README).
    await _client.auth.signInAnonymously();
  }

  // ---- Subscription status ----
  //
  // Source of truth is the `subscriptions` table, one row per
  // ORGANIZATION (business) as of Phase 7 — updated by hand from Table
  // Editor after a Telebirr/bank payment comes in. The app can read its
  // org's row; it can never write tier/expires_at itself.

  Future<SubscriptionStatus> getCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return SubscriptionStatus.freeDefault();
    try {
      return SubscriptionStatus.fromMap(Uri.splitQueryString(raw));
    } catch (_) {
      return SubscriptionStatus.freeDefault();
    }
  }

  Future<void> _cacheStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final map = status.toMap();
    final encoded = map.entries.map((e) => '${e.key}=${e.value}').join('&');
    await prefs.setString(_cacheKey, encoded);
  }

  /// Tries to refresh subscription status from the server. Safe to call
  /// on every app launch and after reconnecting — swallows all errors so
  /// an offline merchant just keeps their last cached status (see the
  /// grace-period logic in SubscriptionStatus.isPremiumActive).
  Future<SubscriptionStatus> refreshStatus(
    String merchantId,
    String shopName,
  ) async {
    try {
      await _ensureSignedIn();
      final orgId = await TeamService.instance.ensureOrganization(
        shopName: shopName,
        ownerPhone: merchantId,
      );
      if (orgId == null) return getCachedStatus();

      final row = await _client
          .from('subscriptions')
          .select()
          .eq('organization_id', orgId)
          .maybeSingle();
      if (row == null) return getCachedStatus();

      final status = SubscriptionStatus(
        tier: PlanTier.values.firstWhere(
          (t) => t.name == row['tier'],
          orElse: () => PlanTier.free,
        ),
        expiresAt: row['expires_at'] != null
            ? DateTime.parse(row['expires_at'] as String)
            : null,
        lastVerifiedAt: DateTime.now(),
      );
      await _cacheStatus(status);
      return status;
    } catch (_) {
      // Offline, server down, anonymous sign-in not enabled yet, etc.
      // — fall back to last cached status rather than surface an error.
      return getCachedStatus();
    }
  }

  // ---- Sync queued local changes ----

  /// Pushes anything DatabaseService has queued (sync_status != 0) up to
  /// Supabase, tagged with both this device's user_id (who entered it —
  /// useful with multiple staff) and the shared organization_id (what
  /// RLS actually checks). Call this opportunistically (e.g. on
  /// connectivity_plus reporting "online") — never on a blocking path.
  Future<void> pushPendingChanges(String merchantId) async {
    String userId;
    String? orgId;
    try {
      await _ensureSignedIn();
      userId = _client.auth.currentUser!.id;
      orgId = await TeamService.instance.getCachedOrganizationId();
      orgId ??= await TeamService.instance
          .ensureOrganization(shopName: 'My Business', ownerPhone: merchantId);
    } catch (_) {
      return; // no connection / auth not set up yet — try again next time
    }
    if (orgId == null) return;

    final db = DatabaseService.instance;
    for (final table in [
      'products',
      'sales',
      'expenses',
      'customers',
      'ledger_entries',
      'suppliers',
      'purchase_orders',
      'purchase_order_lines',
      'branches',
      'branch_stock',
    ]) {
      final pending = await db.getPendingSync(table);
      for (final row in pending) {
        try {
          final remoteRow = Map<String, dynamic>.from(row)
            ..remove('sync_status')
            ..['user_id'] = userId
            ..['created_by'] = userId
            ..['organization_id'] = orgId;
          await _client.from(table).upsert(remoteRow);
          await db.markSynced(table, row['id'] as String);
        } catch (_) {
          // Leave sync_status untouched — retries next time we're
          // online. One row failing shouldn't block the rest.
          continue;
        }
      }
    }
  }
}
