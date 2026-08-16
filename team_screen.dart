import 'package:flutter/material.dart';
import '../services/permissions.dart';
import '../services/team_service.dart';
import '../theme.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  TeamRole _myRole = TeamRole.owner;
  bool _loading = true;
  String? _generatedCode;
  TeamRole _inviteRole = TeamRole.sales;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final role = await TeamService.instance.getCachedRole();
    if (!mounted) return;
    setState(() {
      _myRole = role;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _generatedCode = null;
    });
    final code = await TeamService.instance.createInvite(_inviteRole);
    if (!mounted) return;
    setState(() {
      _generating = false;
      _generatedCode = code;
    });
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ኮድ መፍጠር አልተቻለም — ኢንተርኔት ያረጋግጡ'),
      ));
    }
  }

  String _roleLabel(TeamRole r) => Permissions(r).roleLabel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ቡድን (Team)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('የእርስዎ ሚና (Your role)'),
                    subtitle: Text(_roleLabel(_myRole)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_myRole == TeamRole.owner) ...[
                  const Text('ሰራተኛ ጨምር (Add staff)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'ሚና ይምረጡ፣ ኮድ ይፍጠሩ፣ ለሰራተኛው ይላኩ። እነሱ አፑን ሲከፍቱ '
                    '"በኮድ ግባ" ብለው ኮዱን ያስገባሉ።',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<TeamRole>(
                    initialValue: _inviteRole,
                    decoration: const InputDecoration(labelText: 'ሚና'),
                    items: [TeamRole.sales, TeamRole.warehouse, TeamRole.accountant]
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                        .toList(),
                    onChanged: (r) => setState(() => _inviteRole = r!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: const Icon(Icons.qr_code),
                    label: Text(_generating ? '...' : 'ኮድ ፍጠር'),
                  ),
                  if (_generatedCode != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      color: AppColors.success.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            const Text('የግብዣ ኮድ',
                                style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _generatedCode!,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ] else
                  const Text(
                    'ሰራተኛ መጋበዝ የሚችለው ባለቤቱ (Owner) ብቻ ነው።',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
    );
  }
}
