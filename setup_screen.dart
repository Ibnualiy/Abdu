import 'package:flutter/material.dart';
import '../models/merchant.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../theme.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _showInviteField = false;
  bool _saving = false;
  String? _inviteError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Text('የሱቅዎን መረጃ ያስገቡ',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'ስልክ ቁጥርዎ ለደንበኝነት ምዝገባ (subscription) መለያ ሆኖ ያገለግላል።',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _shopCtrl,
                  decoration: const InputDecoration(labelText: 'የሱቅ ስም'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'ያስፈልጋል' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'ስልክ ቁጥር (Telebirr)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 9)
                      ? 'ትክክለኛ ስልክ ቁጥር ያስገቡ'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _pinCtrl,
                  decoration: const InputDecoration(labelText: '4-ዲጂት PIN ይፍጠሩ'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  validator: (v) =>
                      (v == null || v.length != 4) ? '4 ቁጥር ያስፈልጋል' : null,
                ),
                TextFormField(
                  controller: _pinConfirmCtrl,
                  decoration: const InputDecoration(labelText: 'PIN ያረጋግጡ'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  validator: (v) =>
                      v != _pinCtrl.text ? 'PIN አይመሳሰልም' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_showInviteField)
                  TextButton(
                    onPressed: () => setState(() => _showInviteField = true),
                    child: const Text('የቡድን ግብዣ ኮድ አለኝ (I have a team invite code)'),
                  )
                else
                  TextFormField(
                    controller: _inviteCtrl,
                    decoration: InputDecoration(
                      labelText: 'የግብዣ ኮድ (optional)',
                      errorText: _inviteError,
                      helperText:
                          'ካሉዎት ብቻ ያስገቡ — ባለቤትዎ/አሰሪዎ የላከልዎት ኮድ ካለ',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ጀምር'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _inviteError = null;
    });

    await AuthService.instance.completeSetup(
      profile: MerchantProfile(
        shopName: _shopCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      ),
      pin: _pinCtrl.text,
    );

    final code = _inviteCtrl.text.trim();
    if (code.isNotEmpty) {
      final joined = await TeamService.instance.redeemInvite(code);
      if (!joined) {
        // Local setup (shop/PIN) already succeeded either way — an
        // invalid code shouldn't strand the person outside the app,
        // it just means they start as their own solo organization
        // instead (ensureOrganization will create one on next sync).
        if (mounted) {
          setState(() {
            _saving = false;
            _inviteError = 'ኮዱ ትክክል አይደለም ወይም ኢንተርኔት የለም — ያለ ቡድን ይቀጥላል';
          });
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!mounted) return;
    widget.onDone();
  }
}
