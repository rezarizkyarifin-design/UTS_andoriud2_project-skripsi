import 'user_roles.dart';

class AppUser {
  final String id;
  final String nama;
  final String username;
  final UserRole role;
  final String jabatan;

  const AppUser({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.jabatan,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isPegawai => role == UserRole.pegawai;
}
