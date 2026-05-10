import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
import '../../data.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _namaController = TextEditingController();
  String? _selectedSeksi;
  String? _selectedKecamatan;
  String? _selectedKelurahan;
  String? _selectedJenisHak;
  final _noHakController = TextEditingController();
  final _keperluanController = TextEditingController();

  late final DateTime _tanggalPinjam;
  late final DateTime _tanggalKembali;

  @override
  void initState() {
    super.initState();
    _tanggalPinjam = DateTime.now();
    _tanggalKembali = _tanggalPinjam.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHakController.dispose();
    _keperluanController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day.toString().padLeft(2, '0')} ${bulan[date.month - 1]} ${date.year}';
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget dropdownField(
    String label,
    IconData icon,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged, {
    String? hint,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      isExpanded: true,

      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      hint: hint != null
          ? Text(
              hint,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          : null,

      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),

      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  void _simpanPeminjaman() {
    if (_namaController.text.isEmpty ||
        _selectedSeksi == null ||
        _selectedKecamatan == null ||
        _selectedKelurahan == null ||
        _selectedJenisHak == null ||
        _noHakController.text.isEmpty ||
        _keperluanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lengkapi semua kolom sebelum menyimpan.',
          ),
        ),
      );
      return;
    }

    final peminjaman = Peminjaman(
      nama: _namaController.text.trim(),
      seksi: _selectedSeksi!,
      kecamatan: _selectedKecamatan!,
      kelurahan: _selectedKelurahan!,
      jenisHak: _selectedJenisHak!,
      noHak: _noHakController.text.trim(),
      keperluan: _keperluanController.text.trim(),
      tanggalPinjam: _tanggalPinjam,
      tanggalKembali: _tanggalKembali,
    );

    PeminjamanService.tambah(peminjaman);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data peminjaman berhasil disimpan.',
        ),
      ),
    );

    Navigator.pushNamed(
      context,
      '/barcode',
      arguments: {
        'noHak': peminjaman.noHak,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kelurahanOptions = _selectedKecamatan != null
        ? DummyData.kelurahan[_selectedKecamatan] ?? const <String>[]
        : const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Peminjaman'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              TextFormField(
                controller: _namaController,
                decoration: inputDecoration(
                  'Nama Peminjam',
                  Icons.person,
                ),
              ),

              const SizedBox(height: 16),

              dropdownField(
                'Nama Seksi',
                Icons.apartment,
                DummyData.seksi,
                _selectedSeksi,
                (value) {
                  setState(() {
                    _selectedSeksi = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              dropdownField(
                'Kecamatan',
                Icons.location_city,
                DummyData.kecamatan,
                _selectedKecamatan,
                (value) {
                  setState(() {
                    _selectedKecamatan = value;
                    _selectedKelurahan = null;
                  });
                },
              ),

              const SizedBox(height: 16),

              dropdownField(
                'Kelurahan',
                Icons.location_on,
                kelurahanOptions,
                _selectedKelurahan,
                (value) {
                  setState(() {
                    _selectedKelurahan = value;
                  });
                },
                hint: _selectedKecamatan == null
                    ? 'Pilih kecamatan terlebih dahulu'
                    : kelurahanOptions.isEmpty
                        ? 'Data kelurahan belum tersedia'
                        : null,
              ),

              const SizedBox(height: 16),

              dropdownField(
                'Jenis Hak',
                Icons.description,
                DummyData.jenisHak,
                _selectedJenisHak,
                (value) {
                  setState(() {
                    _selectedJenisHak = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noHakController,
                decoration: inputDecoration(
                  'Nomor Hak',
                  Icons.numbers,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _keperluanController,
                maxLines: 3,
                decoration: inputDecoration(
                  'Keperluan',
                  Icons.assignment,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                enabled: false,
                initialValue: _formatDate(_tanggalPinjam),
                decoration: inputDecoration(
                  'Tanggal Peminjaman',
                  Icons.calendar_month,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                enabled: false,
                initialValue: _formatDate(_tanggalKembali),
                decoration: inputDecoration(
                  'Tanggal Pengembalian',
                  Icons.calendar_today,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  onPressed: _simpanPeminjaman,

                  child: const Text(
                    'Simpan Data',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}