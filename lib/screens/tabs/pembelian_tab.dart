import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/excel_parser.dart';
import '../../services/excel_templates.dart';
import '../../state/period_editor.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

/// Tab Pembelian: input saldo awal & persediaan akhir, upload Excel
/// pembelian bahan baku, lalu hitung HPP (Harga Pokok Penjualan).
///
/// HPP = Saldo Awal + Total Pembelian Bahan Baku - Persediaan Akhir
class PembelianTab extends StatefulWidget {
  const PembelianTab({super.key});

  @override
  State<PembelianTab> createState() => _PembelianTabState();
}

class _PembelianTabState extends State<PembelianTab> {
  bool _loading = false;
  bool _downloading = false;

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final bytes = buildPembelianTemplate();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Template Pembelian',
        fileName: 'Template_Pembelian.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan template: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _uploadExcel(PeriodEditor editor) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    setState(() => _loading = true);
    try {
      final parsed = parsePembelianExcel(bytes);
      editor.applyPembelianExcel(parsed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil memproses ${parsed.barisDiproses} baris, '
            'total pembelian ${formatRupiah(parsed.total)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membaca file: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PeriodEditor>();
    final p = editor.period;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Saldo Persediaan',
          icon: Icons.inventory_2,
          child: Column(
            children: [
              MoneyField(
                label: 'Saldo Awal Persediaan',
                value: p.saldoAwal,
                icon: Icons.first_page,
                onChanged: editor.setSaldoAwal,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Persediaan Akhir',
                value: p.persediaanAkhir,
                icon: Icons.last_page,
                onChanged: editor.setPersediaanAkhir,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Upload Pembelian Bahan Baku',
          icon: Icons.upload_file,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload file Excel daftar pembelian bahan baku (kolom Total/Nominal). '
                'Sistem akan menjumlahkan semuanya otomatis.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _downloading ? null : _downloadTemplate,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_downloading ? 'Menyimpan...' : 'Download Template'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _uploadExcel(editor),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_loading ? 'Memproses...' : 'Upload Excel Pembelian'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MoneyField(
                label: 'Total Pembelian Bahan Baku',
                value: p.totalPembelianBahanBaku,
                icon: Icons.shopping_basket,
                onChanged: editor.setTotalPembelianBahanBaku,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Perhitungan HPP',
          icon: Icons.calculate,
          child: Column(
            children: [
              MoneyDisplayRow(label: 'Saldo Awal', value: p.saldoAwal),
              MoneyDisplayRow(label: '+ Total Pembelian Bahan Baku', value: p.totalPembelianBahanBaku),
              MoneyDisplayRow(label: '- Persediaan Akhir', value: p.persediaanAkhir),
              const Divider(),
              MoneyDisplayRow(
                label: 'HPP (Harga Pokok Penjualan)',
                value: p.hpp,
                bold: true,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
