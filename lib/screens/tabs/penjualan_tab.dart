import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/excel_parser.dart';
import '../../services/excel_templates.dart';
import '../../state/period_editor.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

/// Tab Penjualan: upload Excel penjualan lalu tampilkan total per kategori
/// (QRIS, Cash, EDC, GrabFood, GoFood). Nilainya juga bisa dikoreksi manual.
class PenjualanTab extends StatefulWidget {
  const PenjualanTab({super.key});

  @override
  State<PenjualanTab> createState() => _PenjualanTabState();
}

class _PenjualanTabState extends State<PenjualanTab> {
  bool _loading = false;
  bool _downloading = false;

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final bytes = buildPenjualanTemplate();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Template Penjualan',
        fileName: 'Template_Penjualan.xlsx',
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
      final parsed = parsePenjualanExcel(bytes);
      editor.applyPenjualanExcel(parsed);
      if (!mounted) return;

      if (parsed.tidakDikenali.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ada kategori tidak dikenali'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Baris berikut tidak cocok dengan salah satu dari 9 '
                    'kategori pendapatan yang dikenali, sehingga TIDAK ikut '
                    'dijumlahkan otomatis:',
                  ),
                  const SizedBox(height: 8),
                  ...parsed.tidakDikenali.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${e.key}: ${formatRupiah(e.value)}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total tidak dikenali: ${formatRupiah(parsed.totalTidakDikenali)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Silakan tambahkan manual ke kategori yang sesuai di bawah bila perlu.'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil memproses ${parsed.barisDiproses} baris data penjualan.')),
        );
      }
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
          title: 'Upload Data Penjualan',
          icon: Icons.upload_file,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload file Excel penjualan (berisi kolom Kategori & Nominal, '
                'tanpa Tanggal). Sistem akan menjumlahkan otomatis per '
                'kategori pembayaran.',
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
                    label: Text(_loading ? 'Memproses...' : 'Upload Excel Penjualan'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Total Penjualan per Kategori',
          icon: Icons.category,
          child: Column(
            children: [
              MoneyField(
                label: 'Income Cash',
                value: p.penjualanCash,
                icon: Icons.payments,
                onChanged: editor.setPenjualanCash,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income Qris Mandiri',
                value: p.penjualanQrisMandiri,
                icon: Icons.qr_code,
                onChanged: editor.setPenjualanQrisMandiri,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income EDC On Us',
                value: p.penjualanEdcOnUs,
                icon: Icons.credit_card,
                onChanged: editor.setPenjualanEdcOnUs,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income EDC Off Us',
                value: p.penjualanEdcOffUs,
                icon: Icons.credit_card,
                onChanged: editor.setPenjualanEdcOffUs,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income Gofood',
                value: p.penjualanGofood,
                icon: Icons.delivery_dining,
                onChanged: editor.setPenjualanGofood,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income Grabfood',
                value: p.penjualanGrabfood,
                icon: Icons.delivery_dining,
                onChanged: editor.setPenjualanGrabfood,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income Qris ESB',
                value: p.penjualanQrisEsb,
                icon: Icons.qr_code_2,
                onChanged: editor.setPenjualanQrisEsb,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Income Other',
                value: p.penjualanOther,
                icon: Icons.more_horiz,
                onChanged: editor.setPenjualanOther,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Pendapatan Bunga',
                value: p.pendapatanBunga,
                icon: Icons.account_balance,
                onChanged: editor.setPendapatanBunga,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'SC Terkumpul Periode Ini',
                value: p.scTerkumpul,
                icon: Icons.room_service,
                onChanged: editor.setScTerkumpul,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Total Service Charge (5%) yang sudah termasuk di penjualan di atas -- '
                  'dipakai untuk mengeluarkan SC dari basis Alokasi Laba, karena SC adalah '
                  'hak karyawan (Utang Service Charge 20.3), bukan omset usaha.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Akun Tambahan (Pendapatan Lain-lain)',
          icon: Icons.playlist_add,
          child: CustomAccountsSection(
            items: p.customIncomeItems,
            onItemChanged: editor.updateCustomIncomeItem,
            onItemRemoved: editor.removeCustomIncomeItem,
            onAddItem: () => showAddAccountDialog(
              context,
              title: 'Tambah Akun Pendapatan',
              onAdd: editor.addCustomIncomeItem,
            ),
          ),
        ),
        SectionCard(
          title: 'Total Penjualan',
          icon: Icons.summarize,
          child: MoneyDisplayRow(
            label: 'Total Semua Kategori',
            value: p.totalPenjualan,
            bold: true,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
