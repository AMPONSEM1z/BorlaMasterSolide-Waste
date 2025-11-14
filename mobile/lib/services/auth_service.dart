import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

final supabase = Supabase.instance.client;

class AuthService {
  // ✅ Email/password sign up (and create profile)
  static Future<AuthResponse?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String role, // 'customer' or 'company'
    String? companyType, // Optional: 'Solid Waste' or 'Septic Tank'
    String? avatarPath, // Optional: local file path
    Map<String, dynamic>? extraData, // Optional extra profile/company data
  }) async {
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = res.user;
    if (user == null) return null;

    // 🖼️ Upload logo/avatar if provided
    String? uploadedLogoUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      uploadedLogoUrl =
          await StorageService.uploadAvatar(user.id, File(avatarPath));
    }

    // ✅ Base profile data (for general users)
    final profileData = {
      'id': user.id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'avatar_url': uploadedLogoUrl,
    };

    try {
      // Insert profile
      await supabase.from('profiles').insert(profileData);

      // ✅ If this is a company, also insert into `companies`
      if (role == 'company') {
        // Make sure arrays are not null
        List<String> regionsServed = extraData?['regions_served'] != null
            ? List<String>.from(extraData!['regions_served'])
            : [];
        List<String> townsServed = extraData?['towns_served'] != null
            ? List<String>.from(extraData!['towns_served'])
            : [];

        final companyData = {
          'id': user.id,
          'company_name': fullName,
          'company_type': extraData?['company_type'] ?? companyType,
          'regions_served': regionsServed,
          'towns_served': townsServed,
          'address': extraData?['address'] ?? '',
          'company_logo_url': uploadedLogoUrl,
          'contact_email': email,
        };

        // Use insert() instead of upsert with list issue
        final insertedCompany =
            await supabase.from('companies').insert(companyData).select();

        print('✅ Company inserted: $insertedCompany');
      }

      print('✅ User and company data inserted successfully!');
    } catch (error) {
      print('❌ Error inserting user/company: $error');
    }

    return res;
  }

  // ✅ Sign in with email/password
  static Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return res;
  }

  // ✅ Fetch user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res =
        await supabase.from('profiles').select().eq('id', userId).maybeSingle();

    if (res == null || res.isEmpty) return null;
    return Map<String, dynamic>.from(res);
  }

  // ✅ Google Sign-In (OAuth)
  static Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(OAuthProvider.google);
  }

  // ✅ Logout
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
