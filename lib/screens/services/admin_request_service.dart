import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/admin_request.dart';
import 'auth_service.dart';

/// Backs the "urgent" Admin-role-request banner on the Admin homepage.
///
/// Mirrors PeminjamanService's pattern: an in-memory [_cache] populated by
/// [refresh] (called at startup in main.dart and on pull-to-refresh), read
/// synchronously everywhere else so build() methods don't need
/// FutureBuilders. RLS on `admin_requests` means a Pegawai calling
/// [refresh] just gets an empty list back, not an error — so this is safe
/// to call unconditionally after any login/session restore.
class AdminRequestService {
  AdminRequestService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static final List<AdminRequest> _cache = [];

  static List<AdminRequest> getPending() => List.unmodifiable(_cache);
  static int getPendingCount() => _cache.length;

  static Future<void> refresh() async {
    // Not an admin (or not logged in) — nothing to show, and the RLS
    // policy would return an empty list anyway, so skip the round trip.
    if (!AuthService.isAdmin) {
      _cache.clear();
      return;
    }

    final rows = await _client
        .from('admin_requests')
        .select(
          'id, user_id, alasan, status, created_at, profiles!user_id(nama, jabatan)',
        )
        .eq('status', 'pending')
        .order('created_at');

    _cache
      ..clear()
      ..addAll(
        (rows as List).map(
          (r) => AdminRequest.fromMap(r as Map<String, dynamic>),
        ),
      );
  }

  /// Approves [request]: promotes the requester via the server-side
  /// promote_user_to_admin RPC (never a direct client-side role update —
  /// see the RPC's own SECURITY DEFINER check), then marks the request
  /// resolved. Returns null on success, or a user-facing error message.
  static Future<String?> approve(AdminRequest request) async {
    try {
      await _client.rpc(
        'promote_user_to_admin',
        params: {'target_user_id': request.userId},
      );
      await _client
          .from('admin_requests')
          .update({
            'status': 'approved',
            'resolved_by': AuthService.currentUser?.id,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request.id);
      _cache.removeWhere((r) => r.id == request.id);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal menyetujui permintaan: $e';
    }
  }

  /// Returns null on success, or a user-facing error message.
  static Future<String?> reject(AdminRequest request) async {
    try {
      await _client
          .from('admin_requests')
          .update({
            'status': 'rejected',
            'resolved_by': AuthService.currentUser?.id,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request.id);
      _cache.removeWhere((r) => r.id == request.id);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal menolak permintaan: $e';
    }
  }
}
