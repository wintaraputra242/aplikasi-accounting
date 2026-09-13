import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import '../models/invoice_record.dart';
import '../services/pdf_export.dart';
import '../theme/app_semantic_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import 'business_profile_screen.dart';

/// Layar buat/edit Invoice: isi data penerima & baris item, lalu generate PDF
/// mengikuti layout contoh invoice Mangana Coffee and Space, lengkap dengan
/// kotak kontak person (dari [BusinessProfile]) di pojok kanan bawah. Kalau
/// [existing] diisi, layar ini jadi mode edit invoice yang sudah tersimpan
/// di Riwayat Invoice (update baris, bukan menambah nomor urut baru).
class InvoiceFormScreen extends StatefulWidget {
  final InvoiceRecord? existing;

  const InvoiceFormScreen({super.key, this.existing});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _ItemRowControllers {
  final keterangan = TextEditingController();
  final jumlah = TextEditingController(text: '1');
  final harga = TextEditingController();

  _ItemRowControllers();

  factory _ItemRowControllers.fromItem(InvoiceItem item) {
    final c = _ItemRowControllers();
    c.keterangan.text = item.keterangan;
    c.jumlah.text = item.jumlah.toString();
    c.harga.text = item.harga == 0 ? '' : NumberFormat.decimalPattern('id_ID').format(item.harga.toInt());
    return c;
  }

  void dispose() {
    keterangan.dispose();
    jumlah.dispose();
    harga.dispose();
  }
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  bool _loading = true;
  bool _generating = false;
  BusinessProfile _profile = const BusinessProfile();

  final _noInvoice = TextEditingController();
  final _namaPenerima = TextEditingController();
  final _alamatPenerima = TextEditingController();
  DateTime _tanggalInvoice = DateTime.now();
  late DateTime _jatuhTempo = _tanggalInvoice.add(const Duration(days: 3));

  final List<_ItemRowControllers> _itemRows = [_ItemRowControllers()];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _noInvoice.text = existing.noInvoice;
      _namaPenerima.text = existing.namaPenerima;
      _alamatPenerima.text = existing.alamatPenerima;
      _tanggalInvoice = existing.tanggalInvoice;
      _jatuhTempo = existing.jatuhTempo;
      for (final r in _itemRows) {
        r.dispose();
      }
      _itemRows
        ..clear()
        ..addAll(existing.items.map(_ItemRowControllers.fromItem));
    }
    _load();
  }

  Future<void> _load() async {
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (widget.existing == null) {
        _noInvoice.text = _suggestNoInvoice(profile, _tanggalInvoice);
      }
      _loading = false;
    });
  }

  String _suggestNoInvoice(BusinessProfile profile, DateTime tanggal) {
    final seq = profile.nextInvoiceSeq.toString().padLeft(3, '0');
    final month = tanggal.month.toString().padLeft(2, '0');
    final year = tanggal.year.toString();
    final kode = profile.kodeInvoice.trim();
    return kode.isEmpty ? 'INV/$month/$year/$seq' : 'INV/$month/$year/$kode/$seq';
  }

  Future<void> _pickDate({required bool isTanggalInvoice}) async {
    final initial = isTanggalInvoice ? _tanggalInvoice : _jatuhTempo;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isTanggalInvoice) {
        _tanggalInvoice = picked;
        if (_jatuhTempo.isBefore(picked)) _jatuhTempo = picked.add(const Duration(days: 3));
      } else {
        _jatuhTempo = picked;
      }
    });
  }

  Future<void> _openProfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
    );
    await _load();
  }

  void _addItemRow() => setState(() => _itemRows.add(_ItemRowControllers()));

  void _removeItemRow(int index) {
    setState(() {
      _itemRows[index].dispose();
      _itemRows.removeAt(index);
    });
  }

  double get _totalTagihan {
    var total = 0.0;
    for (final r in _itemRows) {
      final jumlah = int.tryParse(r.jumlah.text) ?? 0;
      final harga = parseFlexibleNumber(r.harga.text);
      total += jumlah * harga;
    }
    return total;
  }

  Future<void> _generate() async {
    final items = _itemRows
        .map((r) => InvoiceItem(
              keterangan: r.keterangan.text.trim(),
              jumlah: int.tryParse(r.jumlah.text) ?? 0,
              harga: parseFlexibleNumber(r.harga.text),
            ))
        .where((item) => item.keterangan.isNotEmpty && item.jumlah > 0 && item.harga > 0)
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi minimal 1 baris item (keterangan, jumlah, harga) dulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_noInvoice.text.trim().isEmpty || _namaPenerima.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Invoice dan Kepada wajib diisi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final inv = InvoiceData(
        noInvoice: _noInvoice.text.trim(),
        tanggalInvoice: _tanggalInvoice,
        jatuhTempo: _jatuhTempo,
        namaPenerima: _namaPenerima.text.trim(),
        alamatPenerima: _alamatPenerima.text.trim(),
        items: items,
      );
      final bytes = await buildInvoicePdf(_profile, inv);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Invoice PDF',
        fileName: '${sanitizeFileName(inv.noInvoice)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;

      final existing = widget.existing;
      if (existing == null) {
        await DatabaseHelper.instance.insertInvoice(InvoiceRecord(
          noInvoice: inv.noInvoice,
          tanggalInvoice: inv.tanggalInvoice,
          jatuhTempo: inv.jatuhTempo,
          namaPenerima: inv.namaPenerima,
          alamatPenerima: inv.alamatPenerima,
          items: items,
          createdAt: DateTime.now(),
        ));
        final updatedProfile = _profile.copyWith(nextInvoiceSeq: _profile.nextInvoiceSeq + 1);
        await DatabaseHelper.instance.saveBusinessProfile(updatedProfile);
        if (!mounted) return;
        setState(() => _profile = updatedProfile);
      } else {
        await DatabaseHelper.instance.updateInvoice(existing.copyWith(
          noInvoice: inv.noInvoice,
          tanggalInvoice: inv.tanggalInvoice,
          jatuhTempo: inv.jatuhTempo,
          namaPenerima: inv.namaPenerima,
          alamatPenerima: inv.alamatPenerima,
          items: items,
        ));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice tersimpan di: $path')),
      );
      if (existing != null && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat invoice: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() {
    _noInvoice.dispose();
    _namaPenerima.dispose();
    _alamatPenerima.dispose();
    for (final r in _itemRows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Buat Invoice' : 'Edit Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (!_profile.isComplete)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: context.semanticColors.warning.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: Icon(Icons.warning_amber, color: context.semanticColors.warning),
                      title: const Text('Profil usaha belum diisi'),
                      subtitle: const Text(
                        'Isi nama usaha, rekening bank, & kontak person dulu supaya '
                        'tercantum otomatis di invoice.',
                      ),
                      trailing: FilledButton(
                        onPressed: _openProfil,
                        child: const Text('Isi Profil'),
                      ),
                    ),
                  ),
                SectionCard(
                  title: 'Info Invoice',
                  icon: Icons.receipt_long,
                  trailing: TextButton.icon(
                    onPressed: _openProfil,
                    icon: const Icon(Icons.storefront, size: 16),
                    label: const Text('Profil Usaha'),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _noInvoice,
                        decoration: const InputDecoration(
                          labelText: 'No Invoice',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isTanggalInvoice: true),
                              icon: const Icon(Icons.event),
                              label: Text('Invoice: ${dateFmt.format(_tanggalInvoice)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isTanggalInvoice: false),
                              icon: const Icon(Icons.event_busy),
                              label: Text('Jatuh Tempo: ${dateFmt.format(_jatuhTempo)}'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Kepada',
                  icon: Icons.person,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _namaPenerima,
                        decoration: const InputDecoration(
                          labelText: 'Nama Penerima',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _alamatPenerima,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Penerima (opsional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Item Tagihan',
                  icon: Icons.list_alt,
                  child: Column(
                    children: [
                      for (var i = 0; i < _itemRows.length; i++) ...[
                        _ItemRowCard(
                          index: i,
                          controllers: _itemRows[i],
                          onChanged: () => setState(() {}),
                          onRemove: _itemRows.length > 1 ? () => _removeItemRow(i) : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _addItemRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Item'),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Total Tagihan',
                  icon: Icons.summarize,
                  child: MoneyDisplayRow(
                    label: 'Total',
                    value: _totalTagihan,
                    bold: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_generating
                        ? 'Membuat PDF...'
                        : (widget.existing == null ? 'Generate Invoice PDF' : 'Simpan & Generate Ulang PDF')),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ItemRowCard extends StatelessWidget {
  final int index;
  final _ItemRowControllers controllers;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _ItemRowCard({
    required this.index,
    required this.controllers,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final jumlah = int.tryParse(controllers.jumlah.text) ?? 0;
    final harga = parseFlexibleNumber(controllers.harga.text);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: onRemove,
                  tooltip: 'Hapus item',
                ),
            ],
          ),
          TextFormField(
            controller: controllers.keterangan,
            decoration: const InputDecoration(
              labelText: 'Keterangan',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers.jumlah,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controllers.harga,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${formatRupiah(jumlah * harga)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
