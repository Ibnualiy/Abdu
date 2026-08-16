import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/merchant.dart';

/// This is a *local app lock*, not a server account — it protects the
/// phone's data from someone picking it up, not a remote identity. That's
/// why it works fully offline: no server round-trip to open the app.
/// `MerchantProfile.phone` is what ties this device to a subscriptions
/// row once we do talk to Supabase (see SupabaseService.refreshStatus).
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _shopNameKey = 'merchant_shop_name';
  static const _phoneKey = 'merchant_phone';
  static const _pinHashKey = 'merchant_pin_hash';

  Future<bool> isSetUp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinHashKey) && prefs.containsKey(_phoneKey);
  }

  Future<MerchantProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_phoneKey);
    final shopName = prefs.getString(_shopNameKey);
    if (phone == null || shopName == null) return null;
    return MerchantProfile(shopName: shopName, phone: phone);
  }

  Future<void> completeSetup({
    required MerchantProfile profile,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopNameKey, profile.shopName);
    await prefs.setString(_phoneKey, profile.phone);
    await prefs.setString(_pinHashKey, _hashPin(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinHashKey);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  String _hashPin(String pin) =>
      sha256.convert(utf8.encode('mapp_salt_v1:$pin')).toString();
}
