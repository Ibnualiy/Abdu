import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class PinScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinScreen({super.key, required this.onUnlocked});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final ok = await AuthService.instance.verifyPin(_pinCtrl.text);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'የተሳሳተ PIN';
        _checking = false;
        _pinCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.info),
                const SizedBox(height: AppSpacing.md),
                const Text('PIN ያስገቡ',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    if (_error != null) setState(() => _error = null);
                    if (v.length == 4) _check();
                  },
                ),
                if (_checking) const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
