import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/journal.dart';
import '../services/journal_service.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/quick_nav.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

/// Layar Transaksi Kas: 4 tab (Kas Masuk / Kas Keluar / Transfer Kas /
/// Settlement QRIS). Tiap form otomatis generate jurnal + posting ke Buku
/// Besar lewat [JournalService] -- pengguna tidak pernah perlu tahu istilah
/// Debit/Kredit (lihat catatan desain di blueprint_revisi_mangana.txt Bagian
/// 2). Tab Settlement QRIS terpisah dari 3 tab lain karena satu transaksinya
/// selalu 3 baris jurnal (Dr Bank, Dr Beban MDR, Cr QRIS Clearing); Kas
/// Masuk/Keluar di [_TransaksiTab] juga boleh lebih dari 2 baris kalau
/// "akun lawan"-nya di-split ke beberapa akun sekaligus.
class KasTransaksiScreen extends StatelessWidget {
  const KasTransaksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const GlAppBarTitle('Transaksi Kas'),
          actions: const [QuickNavButton(current: QuickNavTarget.transaksiKas)],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Kas Masuk'),
              Tab(text: 'Kas Keluar'),
              Tab(text: 'Transfer'),
              Tab(text: 'Settlement QRIS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TransaksiTab(sumber: JournalSumber.kasMasuk),
            _TransaksiTab(sumber: JournalSumber.kasKeluar),
            _TransaksiTab(sumber: JournalSumber.transferKas),
            _SettlementQrisTab(),
          ],
        ),
      ),
    );
  }
}

class _EntryWithLines {
  final JournalEntry entry;
  final List<JournalLine> lines;
  const _EntryWithLines(this.entry, this.lines);

  /// Untuk Transfer Kas selalu 1 baris; untuk Kas Masuk/Keluar sisi akun
  /// lawan boleh lebih dari 1 baris (lihat [JournalService.postKasMasuk]).
  List<JournalLine> get debitLines => lines.where((l) => l.debit > 0).toList();
  List<JournalLine> get kreditLines => lines.where((l) => l.kredit > 0).toList();
  double get jumlah => lines.fold(0.0, (a, l) => a + l.debit);
}

class _TransaksiTab extends StatefulWidget {
  final String sumber;
  const _TransaksiTab({required this.sumber});

  @override
  State<_TransaksiTab> createState() => _TransaksiTabState();
}

class _TransaksiTabState extends State<_TransaksiTab> {
  final _service = JournalService.instance;
  List<_EntryWithLines> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.getAllJournalEntries();
    final filtered = entries.where((e) => e.sumber == widget.sumber).toList();
    final items = <_EntryWithLines>[];
    for (final e in filtered) {
      final lines = await _service.getLinesForEntry(e.id!);
      items.add(_EntryWithLines(e, lines));
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(_EntryWithLines item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi ini?'),
        content: Text(
          '${item.entry.keterangan.isEmpty ? '(tanpa keterangan)' : item.entry.keterangan}\n'
          '${formatRupiah(item.jumlah)}\n\n'
          'Jurnal & posting Buku Besar terkait akan ikut terhapus.',
        ),
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

  Future<void> _addNew() async {
    if (widget.sumber == JournalSumber.kasMasuk) {
      await _showKasMasukKeluarForm(isMasuk: true);
    } else if (widget.sumber == JournalSumber.kasKeluar) {
      await _showKasMasukKeluarForm(isMasuk: false);
    } else {
      await _showTransferForm();
    }
  }

  String _newSplitLineId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _showKasMasukKeluarForm({required bool isMasuk}) async {
    final pihakController = TextEditingController();
    final keteranganController = TextEditingController();
    var tanggal = DateTime.now();
    Account? akunKasBank = kAkunKasBank.first;
    var akunLawanLines = <AccountAmountLine>[AccountAmountLine(id: _newSplitLineId())];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalLawan = akunLawanLines.fold(0.0, (a, l) => a + l.jumlah);
          final isValid = akunKasBank != null &&
              akunLawanLines.every((l) => l.akun != null && l.jumlah > 0);

          return AlertDialog(
            title: Text(isMasuk ? 'Kas Masuk' : 'Kas Keluar'),
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
                    controller: pihakController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isMasuk ? 'Terima Dari' : 'Penerima',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
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
                  AccountPickerField(
                    label: 'Akun Kas/Bank',
                    value: akunKasBank,
                    excludeKodes: [
                      for (final l in akunLawanLines)
                        if (l.akun != null) l.akun!.kode,
                    ],
                    onChanged: (a) => setDialogState(() => akunKasBank = a),
                  ),
                  const SizedBox(height: 16),
                  Text('Akun Lawan', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  AccountAmountSplitSection(
                    items: akunLawanLines,
                    excludeKode: akunKasBank?.kode,
                    onItemChanged: (item) => setDialogState(() {
                      akunLawanLines = [
                        for (final l in akunLawanLines) l.id == item.id ? item : l,
                      ];
                    }),
                    onItemRemoved: (id) => setDialogState(() {
                      akunLawanLines = akunLawanLines.where((l) => l.id != id).toList();
                    }),
                    onAddItem: () => setDialogState(() {
                      akunLawanLines = [...akunLawanLines, AccountAmountLine(id: _newSplitLineId())];
                    }),
                  ),
                  if (akunLawanLines.length > 1) ...[
                    const Divider(),
                    MoneyDisplayRow(label: 'Total', value: totalLawan, bold: true),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || akunKasBank == null) return;
    final akunKasBankKode = akunKasBank!.kode;
    final akunLawanMap = <String, double>{};
    for (final l in akunLawanLines) {
      if (l.akun == null || l.jumlah <= 0) continue;
      akunLawanMap[l.akun!.kode] = (akunLawanMap[l.akun!.kode] ?? 0) + l.jumlah;
    }
    if (akunLawanMap.isEmpty) return;

    if (isMasuk) {
      await _service.postKasMasuk(
        tanggal: tanggal,
        terimaDari: pihakController.text.trim(),
        keterangan: keteranganController.text.trim(),
        akunKasBank: akunKasBankKode,
        akunLawan: akunLawanMap,
      );
    } else {
      await _service.postKasKeluar(
        tanggal: tanggal,
        penerima: pihakController.text.trim(),
        keterangan: keteranganController.text.trim(),
        akunKasBank: akunKasBankKode,
        akunLawan: akunLawanMap,
      );
    }
    await _load();
  }

  Future<void> _showTransferForm() async {
    final keteranganController = TextEditingController();
    var tanggal = DateTime.now();
    var jumlah = 0.0;
    Account? akunSumber = kAkunKasBank.first;
    Account? akunTujuan;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Transfer Kas'),
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
                AccountPickerField(
                  label: 'Dari Akun',
                  value: akunSumber,
                  excludeKode: akunTujuan?.kode,
                  onChanged: (a) => setDialogState(() {
                    akunSumber = a;
                    if (akunTujuan?.kode == a.kode) akunTujuan = null;
                  }),
                ),
                const SizedBox(height: 12),
                AccountPickerField(
                  label: 'Ke Akun',
                  value: akunTujuan,
                  excludeKode: akunSumber?.kode,
                  onChanged: (a) => setDialogState(() => akunTujuan = a),
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
              onPressed: jumlah > 0 && akunSumber != null && akunTujuan != null
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != true || akunSumber == null || akunTujuan == null || jumlah <= 0) return;
    await _service.postTransferKas(
      tanggal: tanggal,
      keterangan: keteranganController.text.trim(),
      jumlah: jumlah,
      akunSumber: akunSumber!.kode,
      akunTujuan: akunTujuan!.kode,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Belum ada transaksi. Tekan tombol + untuk menambah.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final isMasuk = widget.sumber == JournalSumber.kasMasuk;
                      final akunKasBankKode =
                          (isMasuk ? item.debitLines : item.kreditLines).first.akunKode;
                      final akunLawanLines = isMasuk ? item.kreditLines : item.debitLines;
                      final akunKasBank = findAccount(akunKasBankKode)?.nama ?? akunKasBankKode;
                      final akunLawan = akunLawanLines
                          .map((l) => findAccount(l.akunKode)?.nama ?? l.akunKode)
                          .join(', ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            item.entry.pihak.isNotEmpty ? item.entry.pihak : (item.entry.keterangan.isEmpty ? '(tanpa keterangan)' : item.entry.keterangan),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_dateFmt.format(item.entry.tanggal)}\n'
                            '$akunKasBank → $akunLawan'
                            '${item.entry.pihak.isNotEmpty && item.entry.keterangan.isNotEmpty ? '\n${item.entry.keterangan}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatRupiah(item.jumlah), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Theme.of(context).colorScheme.error,
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
        onPressed: _addNew,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}

class _QrisEntry {
  final JournalEntry entry;
  final List<JournalLine> lines;
  const _QrisEntry(this.entry, this.lines);

  /// Baris Dr selain MDR selalu akun Bank tujuan (lihat
  /// [JournalService.postSettlementQris]: selalu Dr Bank, [Dr MDR], Cr QRIS
  /// Clearing).
  JournalLine get bankLine => lines.firstWhere((l) => l.debit > 0 && l.akunKode != '61.4');
  double get jumlahMdr => lines.where((l) => l.akunKode == '61.4').fold(0.0, (a, l) => a + l.debit);
  double get jumlahKotor => lines.where((l) => l.kredit > 0).fold(0.0, (a, l) => a + l.kredit);
}

class _SettlementQrisTab extends StatefulWidget {
  const _SettlementQrisTab();

  @override
  State<_SettlementQrisTab> createState() => _SettlementQrisTabState();
}

class _SettlementQrisTabState extends State<_SettlementQrisTab> {
  final _service = JournalService.instance;
  List<_QrisEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.getAllJournalEntries();
    final filtered = entries.where((e) => e.sumber == JournalSumber.settlementQris).toList();
    final items = <_QrisEntry>[];
    for (final e in filtered) {
      final lines = await _service.getLinesForEntry(e.id!);
      items.add(_QrisEntry(e, lines));
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(_QrisEntry item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus settlement ini?'),
        content: Text(
          '${item.entry.keterangan.isEmpty ? '(tanpa keterangan)' : item.entry.keterangan}\n'
          '${formatRupiah(item.jumlahKotor)}',
        ),
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

  Future<void> _addNew() async {
    final keteranganController = TextEditingController();
    var tanggal = DateTime.now();
    var jumlahKotor = 0.0;
    var jumlahMdr = 0.0;
    Account? akunBank = kAkunBankRekening.isNotEmpty ? kAkunBankRekening.first : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final jumlahBersih = jumlahKotor - jumlahMdr;
          return AlertDialog(
            title: const Text('Settlement QRIS'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pencairan saldo QRIS Clearing ke Bank, dipotong MDR.',
                    style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
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
                  AccountPickerField(
                    label: 'Akun Bank Tujuan',
                    value: akunBank,
                    onChanged: (a) => setDialogState(() => akunBank = a),
                  ),
                  const SizedBox(height: 12),
                  MoneyField(
                    label: 'Jumlah Kotor (dari QRIS Clearing)',
                    value: jumlahKotor,
                    onChanged: (v) => setDialogState(() => jumlahKotor = v),
                  ),
                  const SizedBox(height: 12),
                  MoneyField(
                    label: 'Potongan MDR',
                    value: jumlahMdr,
                    onChanged: (v) => setDialogState(() => jumlahMdr = v),
                  ),
                  const SizedBox(height: 12),
                  MoneyDisplayRow(label: 'Bersih ke Bank', value: jumlahBersih, bold: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keteranganController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (opsional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                onPressed: jumlahKotor > 0 && jumlahMdr >= 0 && jumlahBersih >= 0 && akunBank != null
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || akunBank == null || jumlahKotor <= 0) return;
    await _service.postSettlementQris(
      tanggal: tanggal,
      keterangan: keteranganController.text.trim(),
      jumlahKotor: jumlahKotor,
      jumlahMdr: jumlahMdr,
      akunBankTujuan: akunBank!.kode,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Belum ada settlement. Tekan tombol + untuk menambah.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final akunBankNama = findAccount(item.bankLine.akunKode)?.nama ?? item.bankLine.akunKode;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            item.entry.keterangan.isEmpty ? 'Settlement QRIS' : item.entry.keterangan,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_dateFmt.format(item.entry.tanggal)}\n'
                            'Ke $akunBankNama • MDR ${formatRupiah(item.jumlahMdr)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatRupiah(item.jumlahKotor), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: kAkunBankRekening.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addNew,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
    );
  }
}
