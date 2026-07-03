import '../models/app_user.dart';
import '../models/user_roles.dart';

class AuthService {
  AuthService._();

  static AppUser? _currentUser;
  static AppUser? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;
  static bool get isAdmin => _currentUser?.isAdmin ?? false;
  static bool get isPegawai => _currentUser?.isPegawai ?? false;

  /// Dummy directory. Replace with a real user table once the DB lands —
  /// nothing outside this file needs to change.
  static final List<_MockCredential> _mockAccounts = [
    _MockCredential(
      username: 'admin',
      password: 'cilegonmelesat',
      user: const AppUser(
        id: 'U-001',
        nama: 'Admin Arsip',
        username: 'admin',
        role: UserRole.admin,
        jabatan: 'Kepala Seksi Tata Usaha',
      ),
    ),
    _MockCredential(
      username: 'pegawai',
      password: 'pegawai123',
      user: const AppUser(
        id: 'U-002',
        nama: 'Petugas Arsip',
        username: 'pegawai',
        role: UserRole.pegawai,
        jabatan: 'Pegawai Kantor Pertanahan Cilegon',
      ),
    ),
  ];

  /// Returns true on success and sets [currentUser]. Returns false on
  /// invalid credentials (doesn't throw) so LoginPage can just branch on
  /// the bool instead of wrapping this in try/catch.
  static bool login(String username, String password) {
    for (final account in _mockAccounts) {
      if (account.username == username && account.password == password) {
        _currentUser = account.user;
        return true;
      }
    }
    return false;
  }

  static void logout() {
    _currentUser = null;
  }

  /// DEV-ONLY: flips the current session between Admin and Pegawai without
  /// needing to log out/in, so you can eyeball both role views while
  /// building UI. Wire this to a debug-only button (e.g. long-press on the
  /// drawer header) and strip it before release.
  static void debugSwitchRole() {
    if (_currentUser == null) return;
    final targetRole = _currentUser!.isAdmin
        ? UserRole.pegawai
        : UserRole.admin;
    _currentUser = _mockAccounts
        .firstWhere((a) => a.user.role == targetRole)
        .user;
  }
}

class _MockCredential {
  final String username;
  final String password;
  final AppUser user;

  const _MockCredential({
    required this.username,
    required this.password,
    required this.user,
  });
}
