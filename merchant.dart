/// The one merchant who owns this phone install. `phone` doubles as the
/// merchant_id used to look up subscription status in Supabase, since
/// it's also the number they pay Telebirr from — one identifier, no
/// separate signup step.
class MerchantProfile {
  final String shopName;
  final String phone;

  const MerchantProfile({required this.shopName, required this.phone});

  Map<String, dynamic> toMap() => {'shop_name': shopName, 'phone': phone};

  factory MerchantProfile.fromMap(Map<String, dynamic> map) =>
      MerchantProfile(
        shopName: map['shop_name'] as String,
        phone: map['phone'] as String,
      );
}
