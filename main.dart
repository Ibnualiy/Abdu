import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/setup_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_manager.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op until SUPABASE_URL/SUPABASE_ANON_KEY are passed via --dart-define
  // (see README "Phase 2" section) — app runs fully offline until then.
  await SupabaseService.init();
  runApp(const MerchandisingApp());
}

class MerchandisingApp extends StatelessWidget {
  const MerchandisingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchandising App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootRouter(),
    );
  }
}

enum _RootState { loading, needsSetup, locked, unlocked }

/// First-launch goes to SetupScreen; every launch after that starts
/// locked behind PinScreen. Unlocking starts SyncManager, which is the
/// only thing in the app that ever touches the network.
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  _RootState _state = _RootState.loading;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final setUp = await AuthService.instance.isSetUp();
    if (!mounted) return;
    setState(() => _state = setUp ? _RootState.locked : _RootState.needsSetup);
  }

  void _onUnlocked() {
    SyncManager.instance.start();
    setState(() => _state = _RootState.unlocked);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _RootState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _RootState.needsSetup:
        return SetupScreen(onDone: _onUnlocked);
      case _RootState.locked:
        return PinScreen(onUnlocked: _onUnlocked);
      case _RootState.unlocked:
        return const HomeShell();
    }
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const DashboardScreen(),
    );
  }
}
