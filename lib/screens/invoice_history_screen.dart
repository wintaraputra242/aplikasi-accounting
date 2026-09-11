import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/invoice_record.dart';
import '../services/pdf_export.dart';
import '../utils/formatters.dart';
import '../widgets/quick_nav.dart';
import 'invoice_form_screen.dart';

/// Halaman Riwayat Invoice: daftar semua invoice yang pernah digenerate,
/// dengan aksi Edit, Download ulang PDF, dan Hapus per baris.
class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  late Future<List<InvoiceRecord>> _future;
  int? _downloadingId;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getAllInvoices();
  }

  Future<void> _refresh() async {
    final future = DatabaseHelper.instance.getAllInvoices();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openEdit(InvoiceRecord record) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(existing: record)),
    );
    if (result == true) await _refresh();
  }

  Future<void> _download(InvoiceRecord record) async {
    setState(() => _downloadingId = record.id);
    try {
      final profile = await DatabaseHelper.instance.getBusinessProfile();
      final bytes = await buildInvoicePdf(profile, record.toInvoiceData());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Invoice PDF',
        fileName: '${sanitizeFileName(record.noInvoice)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _confirmDelete(InvoiceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus invoice ${record.noInvoice}?'),
        content: const Text('Invoice ini akan dihapus permanen dari riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteInvoice(record.id!);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Invoice'),
        actions: const [QuickNavButton(current: QuickNavTarget.riwayatInvoice)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<InvoiceRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final invoices = snapshot.data ?? [];
            if (invoices.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Belum ada invoice yang digenerate.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final downloading = _downloadingId == inv.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                    title: Text(inv.noInvoice, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${inv.namaPenerima}\n${dateFmt.format(inv.tanggalInvoice)} • ${formatRupiah(inv.totalTagihan)}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit invoice',
                          onPressed: () => _openEdit(inv),
                        ),
                        IconButton(
                          icon: downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_outlined),
                          tooltip: 'Download PDF',
                          onPressed: downloading ? null : () => _download(inv),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red.shade400,
                          tooltip: 'Hapus invoice',
                          onPressed: () => _confirmDelete(inv),
                        ),
                      ],
                    ),
                    onTap: () => _openEdit(inv),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
