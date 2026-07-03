enum UserRole { admin, pegawai }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.pegawai:
        return 'Pegawai';
    }
  }
}
