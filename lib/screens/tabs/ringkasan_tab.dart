import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/period.dart';
import '../../services/excel_export.dart';
import '../../services/pdf_export.dart';
import '../../state/period_editor.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/report_widgets.dart';

/// Tab Ringkasan: ekspor laporan, laba bersih, komposisi penjualan (grafik
/// donut), breakdown Pendapatan/HPP/Beban, laba rugi, dan tabel rasio
/// keuangan dibandingkan dengan standar ideal industri F&B, plus Analisa
/// Singkat otomatis. Tampilan detailnya ada di widget-widget reusable pada
/// `lib/widgets/report_widgets.dart` (dipakai ulang juga di Ringkasan Tahunan).
class RingkasanTab extends StatefulWidget {
  const RingkasanTab({super.key});

  @override
  State<RingkasanTab> createState() => _RingkasanTabState();
}

class _RingkasanTabState extends State<RingkasanTab> {
  bool _exportingExcel = false;
  bool _exportingPdf = false;

  Future<void> _exportExcel(Period p) async {
    setState(() => _exportingExcel = true);
    try {
      final bytes = buildRingkasanExcel(p);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Ringkasan Excel',
        fileName: 'Ringkasan_${sanitizeFileName(p.label)}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat Excel: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _exportPdf(Period p) async {
    setState(() => _exportingPdf = true);
    try {
      final bytes = await buildRingkasanPdf(p);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Ringkasan PDF',
        fileName: 'Ringkasan_${sanitizeFileName(p.label)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
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
          title: 'Export Laporan',
          icon: Icons.ios_share,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _exportingExcel ? null : () => _exportExcel(p),
                icon: _exportingExcel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.grid_on),
                label: Text(_exportingExcel ? 'Menyimpan...' : 'Export Excel'),
              ),
              FilledButton.icon(
                onPressed: _exportingPdf ? null : () => _exportPdf(p),
                icon: _exportingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_exportingPdf ? 'Menyimpan...' : 'Export PDF'),
              ),
            ],
          ),
        ),
        NetProfitCard(period: p),
        KomposisiPenjualanCard(period: p),
        PendapatanCard(period: p),
        HppCard(period: p),
        BebanOperasionalCard(period: p),
        LabaRugiCard(period: p),
        RasioKeuanganCard(period: p),
        AnalisaSingkatCard(period: p),
      ],
    );
  }
}
