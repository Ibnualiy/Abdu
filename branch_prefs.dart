import 'package:shared_preferences/shared_preferences.dart';

/// Which branch this device is currently operating as. Local-only and
/// per-device on purpose — a phone physically sits at one location at a
/// time, so "current branch" is a device setting, not synced data.
class BranchPrefs {
  static const _key = 'current_branch_id';
  static const _nameKey = 'current_branch_name';

  static Future<void> setCurrent(String? id, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_key);
      await prefs.remove(_nameKey);
    } else {
      await prefs.setString(_key, id);
      await prefs.setString(_nameKey, name ?? '');
    }
  }

  static Future<(String?, String?)> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_key), prefs.getString(_nameKey));
  }
}
