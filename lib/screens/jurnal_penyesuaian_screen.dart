import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/fixed_asset.dart';
import '../models/journal.dart';
import '../models/period.dart';
import '../services/journal_service.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/quick_nav.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

class _AdjEntry {
  final JournalEntry entry;
  final List<JournalLine> lines;
  const _AdjEntry(this.entry, this.lines);

  double get totalDebit => lines.fold(0.0, (a, l) => a + l.debit);
  List<JournalLine> get debitLines => lines.where((l) => l.debit > 0).toList();
  List<JournalLine> get kreditLines => lines.where((l) => l.kredit > 0).toList();
}

/// Layar Jurnal Penyesuaian (Adjusting Entries) -- susulan setelah Kas
/// Masuk/Keluar/Transfer + Buku Besar + Neraca Saldo GL selesai (blueprint
/// Bagian 2 item 6). 5 jenis penyesuaian, semua tetap lewat form terpandu
/// (bukan input Debit/Kredit mentah):
/// 1. Depresiasi -- otomatis dari Fixed Asset Register.
/// 2. Accrued Gaji -- manual, akun sudah ditentukan (Dr Beban Gaji / Cr
///    Hutang Gaji).
/// 3. Accrued Beban Lain -- manual, pilih akun beban, Cr Hutang Usaha.
/// 4. Amortisasi Sewa Dibayar Dimuka -- manual (pembayaran awal sewa
///    dicatat sebagai Kas Keluar dengan akun lawan "Sewa Dibayar Dimuka",
///    lalu tiap bulan porsi terpakainya dipindah ke Beban Sewa di sini).
/// 5. Penyesuaian Persediaan/Waste -- otomatis dari selisih Stock Opname
///    (stok fisik vs stok sistem) pada satu periode.
class JurnalPenyesuaianScreen extends StatefulWidget {
  const JurnalPenyesuaianScreen({super.key});

  @override
  State<JurnalPenyesuaianScreen> createState() => _JurnalPenyesuaianScreenState();
}

class _JurnalPenyesuaianScreenState extends State<JurnalPenyesuaianScreen> {
  final _service = JournalService.instance;
  List<_AdjEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.getAllJournalEntries();
    final filtered = entries.where((e) => e.sumber == JournalSumber.penyesuaian).toList();
    final items = <_AdjEntry>[];
    for (final e in filtered) {
      final lines = await _service.getLinesForEntry(e.id!);
      items.add(_AdjEntry(e, lines));
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(_AdjEntry item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus penyesuaian ini?'),
        content: Text('${item.entry.keterangan}\n${formatRupiah(item.totalDebit)}'),
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
    if (confirm != true) return;
    await _service.deleteJournalEntry(item.entry.id!);
    await _load();
  }

  Future<void> _pickJenis() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Depresiasi (otomatis dari Fixed Asset Register)'),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Accrued Gaji'),
              onTap: () => Navigator.pop(ctx, 2),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Accrued Beban Lain'),
              onTap: () => Navigator.pop(ctx, 3),
            ),
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Amortisasi Sewa Dibayar Dimuka'),
              onTap: () => Navigator.pop(ctx, 4),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Penyesuaian Persediaan/Waste (dari Stock Opname)'),
              onTap: () => Navigator.pop(ctx, 5),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 1) {
      await _showDepresiasiForm();
    } else if (choice == 2) {
      await _showAccruedGajiForm();
    } else if (choice == 3) {
      await _showAccruedBebanLainForm();
    } else if (choice == 4) {
      await _showAmortisasiPrepaidForm();
    } else if (choice == 5) {
      await _showPenyesuaianPersediaanForm();
    }
  }

  Map<String, double> _penyusutanPerKategori(List<FixedAssetItem> assets, DateTime bulan) {
    final start = DateTime(bulan.year, bulan.month, 1);
    final end = DateTime(bulan.year, bulan.month + 1, 0);
    final totals = {for (final k in kKategoriAset) k: 0.0};
    for (final a in assets) {
      if (a.aktifPadaPeriode(start, end)) {
        totals[a.kategori] = (totals[a.kategori] ?? 0) + a.penyusutanPerBulan;
      }
    }
    return totals;
  }

  Future<void> _showDepresiasiForm() async {
    final assets = await DatabaseHelper.instance.getAllFixedAssets();
    if (!mounted) return;
    var bulan = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totals = _penyusutanPerKategori(assets, bulan);
          final total = totals.values.fold(0.0, (a, b) => a + b);

          return AlertDialog(
            title: const Text('Posting Depresiasi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: bulan,
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => bulan = picked);
                    },
                    icon: const Icon(Icons.event),
                    label: Text('Bulan: ${DateFormat('MMMM yyyy', 'id_ID').format(bulan)}'),
                  ),
                  const SizedBox(height: 12),
                  for (final k in kKategoriAset) MoneyDisplayRow(label: k, value: totals[k] ?? 0),
                  const Divider(),
                  MoneyDisplayRow(label: 'Total Depresiasi', value: total, bold: true),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                onPressed: total > 0 ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Posting'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;
    final totals = _penyusutanPerKategori(assets, bulan);
    final end = DateTime(bulan.year, bulan.month + 1, 0);
    await _service.postDepresiasiPeriode(
      tanggal: end,
      keterangan: 'Depresiasi ${DateFormat('MMMM yyyy', 'id_ID').format(bulan)}',
      penyusutanPerKategori: totals,
    );
    await _load();
  }

  Future<void> _showManualForm({
    required String title,
    required String akunDebit,
    required String akunKredit,
    String defaultKeterangan = '',
  }) async {
    final keteranganController = TextEditingController(text: defaultKeterangan);
    var tanggal = DateTime.now();
    var jumlah = 0.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tanggal,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => tanggal = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text('Tanggal: ${_dateFmt.format(tanggal)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keteranganController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                MoneyField(
                  label: 'Jumlah',
                  value: jumlah,
                  onChanged: (v) => setDialogState(() => jumlah = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: jumlah > 0 ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Posting'),
            ),
          ],
        ),
      ),
    );

    if (result != true || jumlah <= 0) return;
    await _service.postPenyesuaian(
      tanggal: tanggal,
      keterangan: keteranganController.text.trim(),
      jumlah: jumlah,
      akunDebit: akunDebit,
      akunKredit: akunKredit,
    );
    await _load();
  }

  Future<void> _showAccruedGajiForm() => _showManualForm(
        title: 'Accrued Gaji',
        akunDebit: '61.1',
        akunKredit: '20.101',
        defaultKeterangan: 'Accrued Gaji Karyawan',
      );

  Future<void> _showAccruedBebanLainForm() async {
    Account? akunBeban;
    final result = await showDialog<Account?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Accrued Beban Lain'),
          content: AccountPickerField(
            label: 'Akun Beban',
            value: akunBeban,
            accounts: kChartOfAccounts.where((a) => a.tipe == AccountType.beban).toList(),
            onChanged: (a) => setDialogState(() => akunBeban = a),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: akunBeban != null ? () => Navigator.pop(ctx, akunBeban) : null,
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _showManualForm(
      title: 'Accrued ${result.nama}',
      akunDebit: result.kode,
      akunKredit: '20.100',
      defaultKeterangan: 'Accrued ${result.nama}',
    );
  }

  Future<void> _showAmortisasiPrepaidForm() => _showManualForm(
        title: 'Amortisasi Sewa Dibayar Dimuka',
        akunDebit: '61.16',
        akunKredit: '13.5',
        defaultKeterangan: 'Amortisasi Sewa Dibayar Dimuka bulan ini',
      );

  Future<double> _computeShrinkageValue(int periodId) async {
    final db = DatabaseHelper.instance;
    final barangs = await db.getAllBarangItems();
    final pembelian = await db.getPembelianItemsByPeriod(periodId);
    final waste = await db.getWasteItemsByPeriod(periodId);
    final opname = await db.getStockOpnameByPeriod(periodId);
    final opnameByBarang = {for (final o in opname) o.barangId: o};

    var totalSelisihValue = 0.0;
    for (final b in barangs.where((b) => b.aktif)) {
      final o = opnameByBarang[b.id];
      if (o == null) continue;
      final totalPembelianQty =
          pembelian.where((p) => p.barangId == b.id).fold(0.0, (a, p) => a + p.qty);
      final totalWasteQty = waste.where((w) => w.barangId == b.id).fold(0.0, (a, w) => a + w.qty);
      final stokSistem = o.stokAwal + totalPembelianQty - totalWasteQty;
      final selisih = o.stokFisik - stokSistem;
      totalSelisihValue += selisih * b.hargaRataRata;
    }
    return totalSelisihValue < 0 ? -totalSelisihValue : 0;
  }

  Future<void> _showPenyesuaianPersediaanForm() async {
    final periods = await DatabaseHelper.instance.getAllPeriods();
    if (!mounted) return;
    if (periods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada periode dengan data Stock.')),
      );
      return;
    }

    Period? selected;
    double? shrinkage;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Penyesuaian Persediaan/Waste'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Period>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Periode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: periods
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (p) async {
                    setDialogState(() {
                      selected = p;
                      shrinkage = null;
                    });
                    if (p?.id != null) {
                      final value = await _computeShrinkageValue(p!.id!);
                      setDialogState(() => shrinkage = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (selected != null)
                  shrinkage == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : MoneyDisplayRow(
                          label: 'Nilai Shrinkage/Waste',
                          value: shrinkage!,
                          bold: true,
                        ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: (shrinkage ?? 0) > 0 ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Posting'),
            ),
          ],
        ),
      ),
    );

    if (result != true || selected == null || shrinkage == null || shrinkage! <= 0) return;
    await _service.postPenyesuaian(
      tanggal: selected!.endDate,
      keterangan: 'Penyesuaian Persediaan/Waste - ${selected!.label}',
      jumlah: shrinkage!,
      akunDebit: '50.6',
      akunKredit: '13.2',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jurnal Penyesuaian'),
        actions: const [QuickNavButton(current: QuickNavTarget.jurnalPenyesuaian)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Belum ada penyesuaian. Tekan tombol + untuk menambah.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final drNames = item.debitLines
                          .map((l) => findAccount(l.akunKode)?.nama ?? l.akunKode)
                          .join(', ');
                      final crNames = item.kreditLines
                          .map((l) => findAccount(l.akunKode)?.nama ?? l.akunKode)
                          .join(', ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            item.entry.keterangan,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_dateFmt.format(item.entry.tanggal)}\nDr: $drNames\nCr: $crNames',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatRupiah(item.totalDebit),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Colors.red.shade400,
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickJenis,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
