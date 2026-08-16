import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Watches for the phone regaining a connection and, when it does, pushes
/// any locally-queued changes and refreshes subscription status. This is
/// the only place "online" and "offline" meet — every screen just reads
/// local SQLite/SharedPreferences and never waits on this.
class SyncManager {
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  void start() {
    _sub ??= Connectivity()
        .onConnectivityChanged
        .listen((results) => _onConnectivityChanged(results));
    // Also try once immediately in case we're already online at launch.
    _attemptSync();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) _attemptSync();
  }

  Future<void> _attemptSync() async {
    if (_syncing) return; // one sync attempt at a time
    final profile = await AuthService.instance.getProfile();
    if (profile == null) return; // setup not completed yet

    _syncing = true;
    try {
      await SupabaseService.instance.pushPendingChanges(profile.phone);
      await SupabaseService.instance
          .refreshStatus(profile.phone, profile.shopName);
    } finally {
      _syncing = false;
    }
  }
}
