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

  // Maps a row from the Supabase `profiles` table. Role is stored as
  // Postgres enum ('admin' | 'pegawai') but comes back over PostgREST as
  // a plain string — matches UserRole's enum names exactly, so
  // `.byName()` works directly.
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      nama: map['nama'] as String,
      username: map['username'] as String,
      role: UserRole.values.byName(map['role'] as String),
      jabatan: map['jabatan'] as String,
    );
  }
}
