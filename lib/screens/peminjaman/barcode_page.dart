import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BarcodePage extends StatelessWidget {
  const BarcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final noHak = args['noHak']!;

    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Pengembalian')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Barcode untuk Pengembalian',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: noHak,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 20),
              Text('No. Hak: $noHak'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/home'),
                child: const Text('Kembali ke Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}