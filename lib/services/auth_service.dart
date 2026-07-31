import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static AppUser? _currentUser;
  static AppUser? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;
  static bool get isAdmin => _currentUser?.isAdmin ?? false;
  static bool get isPegawai => _currentUser?.isPegawai ?? false;

  static String _emailFor(String username) => '$username@siap.local';

  static Future<bool> login(String username, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: _emailFor(username),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) return false;

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();

      _currentUser = AppUser.fromMap(profile);
      return true;
    } on AuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;

    // Reset onboarding flag so the onboarding slides show again on the
    // next app open, instead of only ever showing once per install.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', false);
  }

  static Future<bool> tryRestoreSession() async {
    final authUser = _client.auth.currentSession?.user;
    if (authUser == null) return false;

    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();
      _currentUser = AppUser.fromMap(profile);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // SIGN UP (note item #2) — self-registration always creates a
  // 'pegawai' account, never 'admin'. Admin accounts are provisioned by
  // an existing admin (Supabase dashboard, or a future admin-only
  // "create user" screen) — never by public sign-up, since that would
  // let anyone grant themselves admin by just filling a form.
  // ══════════════════════════════════════════════════════════════════

  /// Returns null on success, or a user-facing error message on failure.
  static Future<String?> signUp({
    required String nama,
    required String username,
    required String jabatan,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return 'Username tidak boleh kosong.';
    if (password.length < 6) return 'Password minimal 6 karakter.';

    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();
      if (existing != null) return 'Username "$cleanUsername" sudah dipakai.';

      final response = await _client.auth.signUp(
        email: _emailFor(cleanUsername),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        return 'Gagal membuat akun. Coba lagi.';
      }

      // If the Supabase project has "Confirm email" turned ON, signUp()
      // won't return an active session, and this insert (which needs
      // auth.uid() = authUser.id per the profiles RLS policy) will fail
      // with a permission error. For the synthetic @siap.local email
      // scheme to work at all, that setting needs to be OFF — see the
      // note in supabase_rls_admin_controls.sql.
      await _client.from('profiles').insert({
        'id': authUser.id,
        'nama': nama.trim(),
        'username': cleanUsername,
        'jabatan': jabatan.trim(),
        'role': 'pegawai',
      });

      if (_client.auth.currentSession != null) {
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .single();
        _currentUser = AppUser.fromMap(profile);
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // PASSWORD CHANGE (note item #8) — a real "forgot password" email
  // flow isn't viable here: accounts sign in with a synthetic
  // '<username>@siap.local' address (see _emailFor above), which isn't
  // a real inbox, so Supabase's resetPasswordForEmail() would send a
  // reset link nobody can receive. This is the self-service equivalent:
  // change your password while already logged in, re-verified with your
  // current password first so a device left unlocked can't be used to
  // lock the real owner out.
  // ══════════════════════════════════════════════════════════════════

  /// Returns null on success, or a user-facing error message on failure.
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Sesi tidak ditemukan, silakan login kembali.';
    if (newPassword.length < 6) return 'Password baru minimal 6 karakter.';

    try {
      // Re-verify identity with the current password before changing it.
      await _client.auth.signInWithPassword(
        email: _emailFor(user.username),
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return 'Password saat ini salah.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
