import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TeamRole { owner, sales, warehouse, accountant }

/// Resolves which organization this device belongs to, creating one on
/// first successful connection if it doesn't have one yet (the RPCs
/// this calls are defined in supabase/migration_phase7_roles.sql — this
/// class is a thin wrapper, all the actual access-control logic lives
/// in Postgres, not here). Once known, organization_id is cached
/// locally so SupabaseService can tag pushed rows with it even before
/// this device is back online.
class TeamService {
  TeamService._internal();
  static final TeamService instance = TeamService._internal();

  static const _orgIdKey = 'organization_id';
  static const _roleKey = 'team_role';

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  Future<String?> getCachedOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_orgIdKey);
  }

  Future<TeamRole> getCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roleKey);
    return TeamRole.values.firstWhere((r) => r.name == raw,
        orElse: () => TeamRole.owner);
  }

  Future<void> _cache(String orgId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orgIdKey, orgId);
    await prefs.setString(_roleKey, role);
  }

  /// Call after every successful sign-in. If this auth.uid() already
  /// belongs to an organization (checked via the memberships table,
  /// which RLS lets you read your own rows from), caches it. Otherwise
  /// — a brand-new device that hasn't redeemed an invite — creates a
  /// new organization via RPC and becomes its owner. Never overwrites
  /// an existing membership, so it's safe to call on every launch.
  Future<String?> ensureOrganization({
    required String shopName,
    required String ownerPhone,
  }) async {
    try {
      await _ensureSignedIn();
      final existing = await _client
          .from('memberships')
          .select('organization_id, role')
          .limit(1)
          .maybeSingle();
      if (existing != null) {
        await _cache(existing['organization_id'] as String,
            existing['role'] as String);
        return existing['organization_id'] as String;
      }

      final orgId = await _client.rpc('create_organization', params: {
        'org_name': shopName,
        'merchant_phone': ownerPhone,
      }) as String;
      await _cache(orgId, 'owner');
      return orgId;
    } catch (_) {
      return getCachedOrganizationId(); // offline — use last known org
    }
  }

  /// Owner-only (enforced by RLS on invites, not just this check) —
  /// generates a short code another device can redeem to join. Returns
  /// null if offline or the caller isn't actually an owner.
  Future<String?> createInvite(TeamRole role) async {
    final orgId = await getCachedOrganizationId();
    if (orgId == null) return null;
    final code = _randomCode();
    try {
      await _client.from('invites').insert({
        'code': code,
        'organization_id': orgId,
        'role': role.name,
        'created_by': _client.auth.currentUser?.id,
      });
      return code;
    } catch (_) {
      return null; // offline, or RLS rejected it (not an owner)
    }
  }

  /// Run once on a new device instead of ensureOrganization, when the
  /// person joining already has a code from their employer.
  Future<bool> redeemInvite(String code) async {
    try {
      await _ensureSignedIn();
      final orgId =
          await _client.rpc('redeem_invite', params: {'invite_code': code})
              as String;
      final membership = await _client
          .from('memberships')
          .select('role')
          .eq('organization_id', orgId)
          .limit(1)
          .maybeSingle();
      await _cache(orgId, membership?['role'] as String? ?? 'sales');
      return true;
    } catch (_) {
      return false; // bad code, already used, or offline
    }
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
