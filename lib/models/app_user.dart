import 'user_roles.dart';

class AppUser {
  final String id;
  final String nama;
  final String username;
  final UserRole role;
  final String jabatan;

  // ─── Real contact email (14.08.2026) — separate from `username`,
  // which is a synthetic '<name>@siap.app' login address, not a real
  // inbox. This is where email notifications actually go. Nullable:
  // not everyone will have filled theirs in.
  final String? contactEmail;

  const AppUser({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.jabatan,
    this.contactEmail,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isPegawai => role == UserRole.pegawai;

  AppUser copyWith({
    String? id,
    String? nama,
    String? username,
    UserRole? role,
    String? jabatan,
    String? contactEmail,
    // BUG FIX: `contactEmail: contactEmail ?? this.contactEmail` can
    // never actually clear the field — passing null to "clear it" just
    // falls back to the old value, so AuthService.updateContactEmail('')
    // wrote null to Supabase correctly but left the in-memory
    // _currentUser (and the offline cache) showing the stale email.
    // Same clearing pattern already used by Peminjaman.copyWith's
    // clearExtension.
    bool clearContactEmail = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      role: role ?? this.role,
      jabatan: jabatan ?? this.jabatan,
      contactEmail: clearContactEmail
          ? null
          : (contactEmail ?? this.contactEmail),
    );
  }

  // Mirrors fromMap — used to persist the logged-in profile locally
  // (see AuthService._cacheUserLocally) so the app can still open to a
  // usable state when there's a valid Supabase session but no network
  // to re-fetch the profile row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'username': username,
      'role': role.name,
      'jabatan': jabatan,
      'contact_email': contactEmail,
    };
  }

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
      contactEmail: map['contact_email'] as String?,
    );
  }
}
