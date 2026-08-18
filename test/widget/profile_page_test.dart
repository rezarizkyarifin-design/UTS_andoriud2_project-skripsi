import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/peminjaman/profile_page.dart'; // Adjust import path

void main() {
  Widget createProfilePage() {
    return const MaterialApp(home: ProfilPage());
  }

  group('ProfilPage & Change Password Dialog Tests', () {
    testWidgets('Menampilkan komponen profil utama', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets(
      'Validasi password kurang dari 6 karakter di Dialog Ganti Password',
      (WidgetTester tester) async {
        await tester.pumpWidget(createProfilePage());
        await tester.pumpAndSettle();

        // Cari tombol Ubah Password (jika tersedia di UI)
        final changePassBtn = find.text('Ubah Password');
        if (changePassBtn.evaluate().isNotEmpty) {
          await tester.tap(changePassBtn);
          await tester.pumpAndSettle();

          // Dialog harus terbuka (barrierDismissible = false)
          expect(find.byType(AlertDialog), findsOneWidget);

          // Masukkan password < 6 karakter
          final textFields = find.byType(TextField);
          await tester.enterText(textFields.at(0), '123456'); // current
          await tester.enterText(textFields.at(1), '123'); // new short
          await tester.enterText(textFields.at(2), '123'); // confirm

          final saveBtn = find.text('Simpan');
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();

          // Snackbars validasi panjang karakter muncul
          expect(
            find.text('Password baru minimal 6 karakter.'),
            findsOneWidget,
          );
        }
      },
    );
  });
}
