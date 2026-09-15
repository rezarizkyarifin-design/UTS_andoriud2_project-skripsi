/// A pending (or resolved) request from a Pegawai account asking to be
/// promoted to Admin — see AuthService.signUp's ADMIN ROLE REQUEST note
/// and the admin_requests table it writes to.
class AdminRequest {
  final String id;
  final String userId;

  // ─── Requester info, read off the joined `profiles` row (see
  // AdminRequestService.fetchPending's `profiles!user_id(...)` select) —
  // so the approval sheet can show who's asking without a second query.
  final String nama;
  final String jabatan;

  /// Why the person says they need Admin access. Collected on the
  // sign-up form when "Admin" is picked (see SignUpPage._alasanController)
  // — nullable only for any request rows filed before this field existed.
  final String? alasan;

  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime createdAt;

  const AdminRequest({
    required this.id,
    required this.userId,
    required this.nama,
    required this.jabatan,
    required this.alasan,
    required this.status,
    required this.createdAt,
  });

  factory AdminRequest.fromMap(Map<String, dynamic> map) {
    // profiles comes back nested under the FK relation name used in the
    // select() — see AdminRequestService.fetchPending.
    final profile = map['profiles'] is Map<String, dynamic>
        ? map['profiles'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return AdminRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      nama: profile['nama'] as String? ?? 'Pengguna',
      jabatan: profile['jabatan'] as String? ?? '-',
      alasan: map['alasan'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
