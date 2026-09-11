import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/period.dart';
import '../utils/formatters.dart';
import 'buku_besar_screen.dart';
import 'business_profile_screen.dart';
import 'fixed_asset_register_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_history_screen.dart';
import 'jurnal_penyesuaian_screen.dart';
import 'kas_transaksi_screen.dart';
import 'master_barang_screen.dart';
import 'neraca_saldo_gl_screen.dart';
import 'period_detail_screen.dart';
import 'rekonsiliasi_bank_screen.dart';
import 'ringkasan_tahunan_screen.dart';

/// Pilihan menu "titik tiga" di AppBar Home -- dikumpulkan jadi satu dropdown
/// (bukan deretan IconButton) supaya judul aplikasi tidak kepotong di layar
/// sempit sekarang jumlah menunya sudah banyak.
enum _MenuAction {
  buatInvoice,
  riwayatInvoice,
  ringkasanTahunan,
  masterBarang,
  fixedAssetRegister,
  transaksiKas,
  bukuBesar,
  neracaSaldoGl,
  jurnalPenyesuaian,
  rekonsiliasiBank,
  profilUsaha,
  backup,
  restore,
}

/// Halaman utama: daftar periode pembukuan yang sudah dibuat, dan tombol
/// untuk menambah periode baru (bulanan atau rentang tanggal custom).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Period>> _future;
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getAllPeriods();
  }

  Future<void> _refresh() async {
    final future = DatabaseHelper.instance.getAllPeriods();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openPeriod(Period p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PeriodDetailScreen(periodId: p.id!)),
    );
    await _refresh();
  }

  Future<void> _addPeriod() async {
    final choice = await showDialog<_NewPeriodChoice>(
      context: context,
      builder: (_) => const _AddPeriodDialog(),
    );
    if (choice == null) return;

    Period period;
    try {
      if (choice.type == PeriodType.calendar) {
        final existing =
            await DatabaseHelper.instance.getCalendarPeriod(choice.month!, choice.year!);
        period = existing ??
            await DatabaseHelper.instance.createCalendarPeriod(choice.month!, choice.year!);
      } else {
        period = await DatabaseHelper.instance.createCustomPeriod(
          startDate: choice.start!,
          endDate: choice.end!,
          customLabel: choice.label,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat periode: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // Periode sudah tersimpan di database pada titik ini. Refresh daftar
    // segera supaya langsung muncul walaupun pengguna belum sempat masuk
    // atau langsung menekan back dari layar detail.
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Periode "${period.label}" berhasil dibuat & tersimpan.')),
    );

    await _openPeriod(period);
  }

  Future<void> _backupDatabase() async {
    setState(() => _backingUp = true);
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      final bytes = await File(dbPath).readAsBytes();
      final tanggal = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup Database',
        fileName: 'backup_aplikasi_accounting_$tanggal.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup database tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  /// Pulihkan database dari file backup `.db` yang dipilih user -- dipakai
  /// mis. setelah aplikasi diinstal ulang & datanya hilang. File database
  /// yang aktif ditimpa langsung dengan isi file backup, lalu daftar
  /// periode dimuat ulang di layar ini tanpa perlu restart aplikasi (kalau
  /// versi skema backup lebih lama, migrasi otomatis tetap jalan seperti
  /// biasa saat file dibuka ulang).
  Future<void> _restoreDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text(
          'Semua data yang ada di aplikasi SEKARANG akan diganti dengan isi '
          'file backup yang dipilih. Data yang belum di-backup akan hilang '
          'permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    setState(() => _restoring = true);
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      // Tulis ke file sementara dulu baru rename menimpa yang asli --
      // supaya kalau penulisan gagal di tengah jalan (mis. disk penuh),
      // database yang sedang dipakai tidak ikut rusak.
      final tmpFile = File('$dbPath.restore_tmp');
      await tmpFile.writeAsBytes(bytes, flush: true);
      await DatabaseHelper.instance.closeDatabase();
      await tmpFile.rename(dbPath);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore berhasil. Data sudah dimuat ulang.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal restore database: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _confirmDelete(Period p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${p.label}?'),
        content: const Text('Semua data pada periode ini akan dihapus permanen.'),
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
      await DatabaseHelper.instance.deletePeriod(p.id!);
      await _refresh();
    }
  }

  void _onMenuSelected(_MenuAction action) {
    if (action == _MenuAction.buatInvoice) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceFormScreen()));
    } else if (action == _MenuAction.riwayatInvoice) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()));
    } else if (action == _MenuAction.ringkasanTahunan) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RingkasanTahunanScreen()));
    } else if (action == _MenuAction.masterBarang) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterBarangScreen()));
    } else if (action == _MenuAction.fixedAssetRegister) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FixedAssetRegisterScreen()),
      );
    } else if (action == _MenuAction.transaksiKas) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const KasTransaksiScreen()));
    } else if (action == _MenuAction.bukuBesar) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BukuBesarScreen()));
    } else if (action == _MenuAction.neracaSaldoGl) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NeracaSaldoGlScreen()));
    } else if (action == _MenuAction.jurnalPenyesuaian) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const JurnalPenyesuaianScreen()));
    } else if (action == _MenuAction.rekonsiliasiBank) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RekonsiliasiBankScreen()));
    } else if (action == _MenuAction.profilUsaha) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileScreen()));
    } else if (action == _MenuAction.backup) {
      _backupDatabase();
    } else if (action == _MenuAction.restore) {
      _restoreDatabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembukuan Usaha'),
        actions: [
          if (_backingUp || _restoring)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            )
          else
            PopupMenuButton<_MenuAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Menu Lainnya',
              onSelected: _onMenuSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MenuAction.buatInvoice,
                  child: _MenuRow(icon: Icons.request_quote_outlined, label: 'Buat Invoice'),
                ),
                PopupMenuItem(
                  value: _MenuAction.riwayatInvoice,
                  child: _MenuRow(icon: Icons.history, label: 'Riwayat Invoice'),
                ),
                PopupMenuItem(
                  value: _MenuAction.ringkasanTahunan,
                  child: _MenuRow(icon: Icons.calendar_view_month, label: 'Ringkasan Tahunan'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.masterBarang,
                  child: _MenuRow(icon: Icons.inventory_2_outlined, label: 'Master Barang'),
                ),
                PopupMenuItem(
                  value: _MenuAction.fixedAssetRegister,
                  child: _MenuRow(icon: Icons.inventory, label: 'Fixed Asset Register'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.transaksiKas,
                  child: _MenuRow(icon: Icons.payments_outlined, label: 'Transaksi Kas'),
                ),
                PopupMenuItem(
                  value: _MenuAction.bukuBesar,
                  child: _MenuRow(icon: Icons.menu_book_outlined, label: 'Buku Besar'),
                ),
                PopupMenuItem(
                  value: _MenuAction.neracaSaldoGl,
                  child: _MenuRow(icon: Icons.balance_outlined, label: 'Neraca Saldo (GL)'),
                ),
                PopupMenuItem(
                  value: _MenuAction.jurnalPenyesuaian,
                  child: _MenuRow(icon: Icons.tune, label: 'Jurnal Penyesuaian'),
                ),
                PopupMenuItem(
                  value: _MenuAction.rekonsiliasiBank,
                  child: _MenuRow(icon: Icons.account_balance_outlined, label: 'Rekonsiliasi Bank'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.profilUsaha,
                  child: _MenuRow(icon: Icons.storefront_outlined, label: 'Profil Usaha'),
                ),
                PopupMenuItem(
                  value: _MenuAction.backup,
                  child: _MenuRow(icon: Icons.backup_outlined, label: 'Backup Database'),
                ),
                PopupMenuItem(
                  value: _MenuAction.restore,
                  child: _MenuRow(icon: Icons.settings_backup_restore, label: 'Restore Database'),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Period>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final periods = snapshot.data ?? [];
            if (periods.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Belum ada periode.\nTekan tombol + untuk mulai.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final labaBersih = p.labaBersih;
                final positive = labaBersih >= 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor:
                          positive ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        positive ? Icons.trending_up : Icons.trending_down,
                        color: positive ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Laba bersih: ${formatRupiah(labaBersih)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red.shade400,
                          tooltip: 'Hapus periode',
                          onPressed: () => _confirmDelete(p),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _openPeriod(p),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPeriod,
        icon: const Icon(Icons.add),
        label: const Text('Periode Baru'),
      ),
    );
  }
}

/// Hasil pilihan pengguna dari [_AddPeriodDialog].
class _NewPeriodChoice {
  final PeriodType type;
  final int? month;
  final int? year;
  final DateTime? start;
  final DateTime? end;
  final String? label;

  _NewPeriodChoice.calendar(this.month, this.year)
      : type = PeriodType.calendar,
        start = null,
        end = null,
        label = null;

  _NewPeriodChoice.custom(this.start, this.end, this.label)
      : type = PeriodType.custom,
        month = null,
        year = null;
}

class _AddPeriodDialog extends StatefulWidget {
  const _AddPeriodDialog();

  @override
  State<_AddPeriodDialog> createState() => _AddPeriodDialogState();
}

class _AddPeriodDialogState extends State<_AddPeriodDialog> {
  final _now = DateTime.now();
  PeriodType _type = PeriodType.calendar;

  late int _month = _now.month;
  late int _year = _now.year;

  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_rangeStart ?? _now) : (_rangeEnd ?? _rangeStart ?? _now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_now.year - 3),
      lastDate: DateTime(_now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
        if (_rangeEnd != null && _rangeEnd!.isBefore(picked)) _rangeEnd = null;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  bool get _canSubmit {
    if (_type == PeriodType.calendar) return true;
    return _rangeStart != null && _rangeEnd != null && !_rangeEnd!.isBefore(_rangeStart!);
  }

  void _submit() {
    if (!_canSubmit) return;
    if (_type == PeriodType.calendar) {
      Navigator.pop(context, _NewPeriodChoice.calendar(_month, _year));
    } else {
      final label = _labelController.text.trim();
      Navigator.pop(
        context,
        _NewPeriodChoice.custom(_rangeStart!, _rangeEnd!, label.isEmpty ? null : label),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    return AlertDialog(
      title: const Text('Tambah Periode Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<PeriodType>(
              segments: const [
                ButtonSegment(
                  value: PeriodType.calendar,
                  label: Text('Bulanan'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: PeriodType.custom,
                  label: Text('Rentang Tanggal'),
                  icon: Icon(Icons.date_range),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            if (_type == PeriodType.calendar) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Bulan'),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(Period.monthNames[m - 1]),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _month = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Tahun'),
                      items: List.generate(6, (i) => _now.year - 2 + i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Cocok untuk siklus laporan yang tidak mengikuti bulan kalender, '
                'mis. 26 Juni - 25 Juli.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isStart: true),
                icon: const Icon(Icons.event),
                label: Text(_rangeStart == null ? 'Pilih Tanggal Mulai' : dateFmt.format(_rangeStart!)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isStart: false),
                icon: const Icon(Icons.event),
                label: Text(_rangeEnd == null ? 'Pilih Tanggal Akhir' : dateFmt.format(_rangeEnd!)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (opsional)',
                  hintText: 'mis. Periode Juni-Juli',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _canSubmit ? _submit : null, child: const Text('Buat')),
      ],
    );
  }
}

/// Baris ikon + label dipakai tiap [PopupMenuItem] di menu titik tiga Home
/// -- [PopupMenuItem] sendiri tidak punya parameter `leading` seperti
/// [ListTile], jadi disusun manual lewat [Row].
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
