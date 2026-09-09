import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_user.dart';

/// Thrown by [AuthService.login] specifically when the request never
/// reached Supabase at all (no internet / DNS lookup failed), so callers
/// can tell "you're offline" apart from "wrong username/password" instead
/// of both collapsing into the same generic failure.
class NetworkException implements Exception {
  const NetworkException([
    this.message = 'Tidak ada koneksi internet. Coba lagi nanti.',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// True for connectivity-flavored failures (DNS lookup failed, socket
/// couldn't connect, request timed out, etc.) as opposed to a real server
/// response — e.g. an actual "wrong password" (AuthException) or "row not
/// found" (PostgrestException). Supabase's client wraps these in a
/// ClientException, which isn't safe to import directly here (it'd add a
/// direct package:http dependency this file doesn't otherwise need), so
/// this checks by type where possible and falls back to message text.
///
/// Important: Supabase's signInWithPassword() frequently wraps a genuine
/// connectivity failure in an AuthException too, not just a raw
/// SocketException — so this must be checked before deciding an
/// AuthException means "wrong credentials", not only in a fallback
/// catch(e) that an `on AuthException catch` clause would never reach.
bool _isNetworkError(Object e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return true;
  // AuthException/PostgrestException carry the real underlying text in
  // .message, not necessarily in toString() — check both so this isn't
  // sensitive to which one actually contains the useful text.
  final text = [
    e.toString(),
    if (e is AuthException) e.message,
    if (e is PostgrestException) e.message,
  ].join(' ').toLowerCase();

  const networkPhrases = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'connection failed',
    'connection reset',
    'connection refused',
    'connection timed out',
    'network is unreachable',
    'handshakeexception',
    'timeoutexception',
    'no address associated with hostname',
    'software caused connection abort',
  ];
  return networkPhrases.any(text.contains);
}

class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static AppUser? _currentUser;
  static AppUser? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;
  static bool get isAdmin => _currentUser?.isAdmin ?? false;
  static bool get isPegawai => _currentUser?.isPegawai ?? false;

  /// True when the current session was restored from local cache while
  /// offline, rather than confirmed fresh against Supabase. Screens can
  /// use this to show a small "mode offline" indicator if useful.
  static bool isOfflineSession = false;

  static const _cachedUserKey = 'cached_user_profile';

  /// Persists the logged-in profile so [tryRestoreSession] can still open
  /// the app to a usable state on a later launch with no network, as
  /// long as the Supabase SDK's own local session (which it persists
  /// itself) hasn't expired.
  static Future<void> _cacheUserLocally(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
  }

  static Future<AppUser?> _loadCachedUser(String expectedId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['id'] != expectedId) return null;
      return AppUser.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  // NOTE: previously used '@siap.local' — Supabase Auth's server-side
  // email validator rejects that domain, since ".local" is an IANA
  // "special-use" TLD (reserved for mDNS, per RFC 6762) and isn't
  // considered a valid email domain by most format validators,
  // Supabase's included. ".app" doesn't have that reservation, so this
  // synthetic address passes format validation — Supabase only checks
  // the format here, it doesn't verify the domain is real or that mail
  // can actually be delivered to it.
  //
  // This is used two ways: (1) to build the real address Supabase Auth
  // signs in/up with, from whatever bare identifier (e.g. "admin") the
  // user types into the Login/Sign Up form, and (2) as the value
  // actually stored in profiles.username — so profiles.username always
  // holds the full synthetic email (e.g. "admin@siap.app"), matching
  // how existing rows in the table are formatted, rather than the bare
  // identifier alone.
  static String _emailFor(String username) => '$username@siap.app';

  /// Returns false for a genuine auth failure (wrong username/password).
  /// Throws [NetworkException] if the request never reached Supabase at
  /// all — callers should catch that separately and show "tidak ada
  /// koneksi" instead of "username/password salah".
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
      isOfflineSession = false;
      await _cacheUserLocally(_currentUser!);
      return true;
    } catch (e) {
      // Network check goes first, regardless of exception type — Supabase
      // frequently wraps a genuine connectivity failure in an
      // AuthException too, not just a raw SocketException. A separate
      // `on AuthException catch` clause ahead of this would catch those
      // first and misreport them as "wrong password" before this check
      // ever ran (that was the previous bug here).
      if (_isNetworkError(e)) throw const NetworkException();
      // Anything else (AuthException = wrong credentials, or any other
      // unexpected failure) is treated the same way this always was:
      // a plain "login failed" the caller shows as wrong username/password.
      return false;
    }
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
    isOfflineSession = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
    // Reset onboarding flag so the onboarding slides show again on the
    // next app open, instead of only ever showing once per install.
    await prefs.setBool('onboarding_seen', false);
  }

  /// Called on app start (see main.dart). Supabase's SDK persists its own
  /// session locally, so `currentSession` here doesn't need network — but
  /// fetching the profile row normally does. If that fetch fails because
  /// there's no connectivity, this falls back to the profile cached by
  /// the last successful login/restore instead of forcing the user back
  /// to the login screen just because they opened the app offline.
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
      isOfflineSession = false;
      await _cacheUserLocally(_currentUser!);
      return true;
    } catch (e) {
      if (_isNetworkError(e)) {
        final cached = await _loadCachedUser(authUser.id);
        if (cached != null) {
          _currentUser = cached;
          isOfflineSession = true;
          return true;
        }
      }
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

    // The full synthetic email — this is what actually gets stored in
    // profiles.username (see _emailFor's doc comment above), so the
    // duplicate check below has to compare against this same format,
    // not the bare cleanUsername, or it'd miss real collisions against
    // rows already stored this way.
    final email = _emailFor(cleanUsername);

    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', email)
          .maybeSingle();
      if (existing != null) return 'Username "$cleanUsername" sudah dipakai.';

      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        return 'Gagal membuat akun. Coba lagi.';
      }

      // Uses upsert (not insert): if a Supabase DB trigger on auth.users
      // (e.g. a "handle_new_user" function) already auto-created a
      // profiles row for this id — typically with placeholder values
      // like 'Pengguna Baru' / '-', since the trigger has no way to see
      // what was typed into this form — insert() would fail here on a
      // primary-key conflict, silently leaving that placeholder row in
      // place. upsert() overwrites it with the real submitted data
      // instead. If no such trigger exists, this behaves like a normal
      // insert.
      await _client.from('profiles').upsert({
        'id': authUser.id,
        'nama': nama.trim(),
        'username': email,
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
        isOfflineSession = false;
        await _cacheUserLocally(_currentUser!);
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      // BUG FIX: this used to return e.toString() straight to the UI —
      // for a plain connectivity failure that's a raw
      // "ClientException with SocketException: Failed host lookup:
      // '<project>.supabase.co' ..., uri=https://<project>.supabase.co/
      // rest/v1/..." string, leaking the project's internal REST
      // endpoint (and whatever id/filter was in the query) straight onto
      // the screen instead of the friendly offline message this app uses
      // everywhere else (see NetworkException / _isNetworkError above).
      if (_isNetworkError(e)) return const NetworkException().message;
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // PASSWORD CHANGE (note item #8) — a real "forgot password" email
  // flow isn't viable here: accounts sign in with a synthetic
  // '<username>@siap.app' address (see _emailFor above), which isn't
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
      // user.username is ALREADY the full synthetic email (see
      // _emailFor's doc comment) — do not wrap it in _emailFor() again
      // here, that would double up the domain (e.g.
      // "admin@siap.app@siap.app") and always fail.
      await _client.auth.signInWithPassword(
        email: user.username,
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
      // BUG FIX: this used to return e.toString() straight to the UI —
      // for a plain connectivity failure that's a raw
      // "ClientException with SocketException: Failed host lookup:
      // '<project>.supabase.co' ..., uri=https://<project>.supabase.co/
      // rest/v1/..." string, leaking the project's internal REST
      // endpoint (and whatever id/filter was in the query) straight onto
      // the screen instead of the friendly offline message this app uses
      // everywhere else (see NetworkException / _isNetworkError above).
      if (_isNetworkError(e)) return const NetworkException().message;
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CHANGE USERNAME (14.08.2026) — takes a bare handle (e.g. "admin",
  // never "admin@siap.app"), rebuilds the full synthetic login address
  // via _emailFor, and keeps THREE things in sync together: Supabase
  // Auth's own email (what login actually checks), profiles.username
  // (what the rest of the app reads via AppUser.username), and the
  // locally-cached profile (so an offline reopen doesn't show a stale
  // username). Getting any one of these out of sync with the others is
  // exactly the "Username shows admin1@siap.app but Email shows
  // admin@siap.app" bug this replaces.
  // ══════════════════════════════════════════════════════════════════

  /// Returns null on success, or a user-facing error message on failure.
  static Future<String?> changeUsername(String newUsername) async {
    final user = _currentUser;
    if (user == null) return 'Sesi tidak ditemukan, silakan login kembali.';

    final cleanUsername = newUsername.trim().toLowerCase();
    if (cleanUsername.isEmpty) return 'Username tidak boleh kosong.';
    if (cleanUsername.contains(' ')) return 'Username tidak boleh ada spasi.';

    final newEmail = _emailFor(cleanUsername);
    if (newEmail == user.username) return null; // no-op, unchanged

    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', newEmail)
          .maybeSingle();
      if (existing != null && existing['id'] != user.id) {
        return 'Username "$cleanUsername" sudah dipakai.';
      }

      // BUG FIX: this used to update Supabase Auth's email first, then
      // profiles.username second. If the second step failed (dropped
      // connection, or the person the app just approved happens to
      // collide with the new profiles_username_key UNIQUE constraint
      // in a race), Auth's email had already changed but
      // profiles.username hadn't — leaving the two permanently out of
      // sync until someone fixed it by hand. Worse, the person would be
      // locked out: the app still shows their old username, but Auth
      // only accepts the new email now.
      //
      // Now: if the profiles write fails after the Auth email already
      // changed, immediately revert Auth's email back to the old value
      // so a failure leaves BOTH unchanged instead of half-changed, and
      // report a clear "try again" error instead of a silent split.
      await _client.auth.updateUser(UserAttributes(email: newEmail));
      try {
        await _client
            .from('profiles')
            .update({'username': newEmail})
            .eq('id', user.id);
      } catch (e) {
        try {
          await _client.auth.updateUser(UserAttributes(email: user.username));
        } catch (_) {
          // Best-effort revert — if even this fails, the account is left
          // with Auth email == newEmail but profiles.username == old.
          // Surface that clearly rather than pretending it's fine.
          return 'Gagal mengubah username, dan gagal memulihkan email '
              'login sebelumnya. Segera hubungi admin — jangan logout '
              'sebelum ini diperbaiki.';
        }
        return 'Gagal mengubah username, silakan coba lagi.';
      }

      _currentUser = user.copyWith(username: newEmail);
      await _cacheUserLocally(_currentUser!);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      // BUG FIX: this used to return e.toString() straight to the UI —
      // for a plain connectivity failure that's a raw
      // "ClientException with SocketException: Failed host lookup:
      // '<project>.supabase.co' ..., uri=https://<project>.supabase.co/
      // rest/v1/..." string, leaking the project's internal REST
      // endpoint (and whatever id/filter was in the query) straight onto
      // the screen instead of the friendly offline message this app uses
      // everywhere else (see NetworkException / _isNetworkError above).
      if (_isNetworkError(e)) return const NetworkException().message;
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CONTACT EMAIL (14.08.2026, Layer 2 notifications) — a real inbox
  // for email notifications, completely separate from `username` (the
  // synthetic login address above). Never touches Supabase Auth at all
  // — this is just a plain profiles column, not a login credential.
  // ══════════════════════════════════════════════════════════════════

  /// Returns null on success, or a user-facing error message on failure.
  /// Pass an empty string to clear a previously-set contact email.
  static Future<String?> updateContactEmail(String email) async {
    final user = _currentUser;
    if (user == null) return 'Sesi tidak ditemukan, silakan login kembali.';

    final trimmed = email.trim();
    if (trimmed.isNotEmpty) {
      final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailPattern.hasMatch(trimmed)) {
        return 'Format email tidak valid.';
      }
    }

    try {
      await _client
          .from('profiles')
          .update({'contact_email': trimmed.isEmpty ? null : trimmed})
          .eq('id', user.id);
      _currentUser = user.copyWith(
        contactEmail: trimmed.isEmpty ? null : trimmed,
        clearContactEmail: trimmed.isEmpty,
      );
      await _cacheUserLocally(_currentUser!);
      return null;
    } catch (e) {
      // BUG FIX: this used to return e.toString() straight to the UI —
      // for a plain connectivity failure that's a raw
      // "ClientException with SocketException: Failed host lookup:
      // '<project>.supabase.co' ..., uri=https://<project>.supabase.co/
      // rest/v1/..." string, leaking the project's internal REST
      // endpoint (and whatever id/filter was in the query) straight onto
      // the screen instead of the friendly offline message this app uses
      // everywhere else (see NetworkException / _isNetworkError above).
      if (_isNetworkError(e)) return const NetworkException().message;
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // DISPLAY NAME (nama) — unlike username above, this is just a plain
  // profiles column with no email-format constraint, so spaces are
  // fine ("Naira Tahira"). Never touches Supabase Auth or the login
  // username — purely cosmetic, shown around the app wherever a
  // person's name is displayed.
  // ══════════════════════════════════════════════════════════════════

  /// Returns null on success, or a user-facing error message on failure.
  static Future<String?> updateNama(String newNama) async {
    final user = _currentUser;
    if (user == null) return 'Sesi tidak ditemukan, silakan login kembali.';

    final trimmed = newNama.trim();
    if (trimmed.isEmpty) return 'Nama tidak boleh kosong.';

    try {
      await _client
          .from('profiles')
          .update({'nama': trimmed})
          .eq('id', user.id);
      _currentUser = user.copyWith(nama: trimmed);
      await _cacheUserLocally(_currentUser!);
      return null;
    } catch (e) {
      // BUG FIX: this used to return e.toString() straight to the UI —
      // for a plain connectivity failure that's a raw
      // "ClientException with SocketException: Failed host lookup:
      // '<project>.supabase.co' ..., uri=https://<project>.supabase.co/
      // rest/v1/..." string, leaking the project's internal REST
      // endpoint (and whatever id/filter was in the query) straight onto
      // the screen instead of the friendly offline message this app uses
      // everywhere else (see NetworkException / _isNetworkError above).
      if (_isNetworkError(e)) return const NetworkException().message;
      return e.toString();
    }
  }
}
