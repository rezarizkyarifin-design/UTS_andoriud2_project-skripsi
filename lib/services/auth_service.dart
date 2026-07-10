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

  // NOTE: `profiles.username` isn't a real Supabase Auth identifier —
  // Auth signs in by email. This assumes accounts were created with
  // email = '<username>@siap.local' (a common pattern when the app only
  // ever shows users a "username"). If your `profiles` table already
  // stores a real email column instead, swap the two lines below for:
  //   final row = await _client.from('profiles').select()
  //       .eq('username', username).maybeSingle();
  //   final email = row?['email'] as String?;
  static String _emailFor(String username) => '$username@siap.local';

  /// Returns true on success and sets [currentUser]. Returns false on
  /// invalid credentials (doesn't throw) so LoginPage can just branch on
  /// the bool instead of wrapping this in try/catch.
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
}
