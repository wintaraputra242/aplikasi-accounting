import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/bank_reconciliation.dart';
import '../services/journal_service.dart';
import '../theme/app_semantic_colors.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/quick_nav.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

/// Layar Rekonsiliasi Bank -- susulan setelah Jurnal Penyesuaian (blueprint
/// Bagian 2 item 7). Belum ada desain konkret dari blueprint asli, jadi ini
/// pakai worksheet rekonsiliasi 2 kolom standar (lihat penjelasan lengkap di
/// lib/models/bank_reconciliation.dart) -- bisa direvisi kalau ada masukan
/// lebih spesifik dari istri pengguna.
class RekonsiliasiBankScreen extends StatefulWidget {
  const RekonsiliasiBankScreen({super.key});

  @override
  State<RekonsiliasiBankScreen> createState() => _RekonsiliasiBankScreenState();
}

class _RekonsiliasiBankScreenState extends State<RekonsiliasiBankScreen> {
  List<BankReconciliation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await DatabaseHelper.instance.getAllBankReconciliations();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(BankReconciliation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus rekonsiliasi ini?'),
        content: Text('${findAccount(r.akunKode)?.nama ?? r.akunKode} - ${_dateFmt.format(r.tanggalCutoff)}'),
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
    await DatabaseHelper.instance.deleteBankReconciliation(r.id!);
    await _load();
  }

  Future<void> _openNew() async {
    Account? akun = kAkunBankRekening.isNotEmpty ? kAkunBankRekening.first : null;
    var tanggal = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rekonsiliasi Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountPickerField(
                label: 'Akun Bank',
                value: akun,
                onChanged: (a) => setDialogState(() => akun = a),
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
                label: Text('Tanggal Cutoff: ${_dateFmt.format(tanggal)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: akun != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );

    if (result != true || akun == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RekonsiliasiDetailScreen(akunKode: akun!.kode, tanggalCutoff: tanggal),
      ),
    );
    await _load();
  }

  Future<void> _openExisting(BankReconciliation r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RekonsiliasiDetailScreen(
          akunKode: r.akunKode,
          tanggalCutoff: r.tanggalCutoff,
          existing: r,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const GlAppBarTitle('Rekonsiliasi Bank'),
        actions: const [QuickNavButton(current: QuickNavTarget.rekonsiliasiBank)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('Belum ada rekonsiliasi. Tekan tombol + untuk membuat.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final r = _items[i];
                      final akun = findAccount(r.akunKode);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(akun?.nama ?? r.akunKode, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${_dateFmt.format(r.tanggalCutoff)}\n'
                            'Saldo Rekening Koran: ${formatRupiah(r.saldoRekeningKoran)}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _delete(r),
                          ),
                          onTap: () => _openExisting(r),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.add),
        label: const Text('Baru'),
      ),
    );
  }
}

class _RekonsiliasiDetailScreen extends StatefulWidget {
  final String akunKode;
  final DateTime tanggalCutoff;
  final BankReconciliation? existing;

  const _RekonsiliasiDetailScreen({
    required this.akunKode,
    required this.tanggalCutoff,
    this.existing,
  });

  @override
  State<_RekonsiliasiDetailScreen> createState() => _RekonsiliasiDetailScreenState();
}

class _RekonsiliasiDetailScreenState extends State<_RekonsiliasiDetailScreen> {
  bool _loading = true;
  double _saldoBuku = 0;
  BankReconciliation? _saved;
  List<BankReconciliationItem> _items = [];
  double _saldoRekeningKoran = 0;
  final _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _saved = widget.existing;
    _load();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final saldoBuku = await JournalService.instance.getSaldoGlAsOf(widget.akunKode, widget.tanggalCutoff);
    var items = <BankReconciliationItem>[];
    if (_saved?.id != null) {
      items = await DatabaseHelper.instance.getBankReconciliationItems(_saved!.id!);
    }
    if (!mounted) return;
    setState(() {
      _saldoBuku = saldoBuku;
      _saldoRekeningKoran = _saved?.saldoRekeningKoran ?? 0;
      _catatanController.text = _saved?.catatan ?? '';
      _items = items;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saved == null) {
      _saved = await DatabaseHelper.instance.insertBankReconciliation(BankReconciliation(
        akunKode: widget.akunKode,
        tanggalCutoff: widget.tanggalCutoff,
        saldoRekeningKoran: _saldoRekeningKoran,
        catatan: _catatanController.text.trim(),
        createdAt: DateTime.now(),
      ));
    } else {
      final updated = _saved!.copyWith(
        saldoRekeningKoran: _saldoRekeningKoran,
        catatan: _catatanController.text.trim(),
      );
      await DatabaseHelper.instance.updateBankReconciliation(updated);
      _saved = updated;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rekonsiliasi tersimpan.')),
    );
    setState(() {});
  }

  Future<void> _addItem() async {
    if (_saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simpan rekonsiliasi dulu sebelum menambah item.')),
      );
      return;
    }
    var tipe = BankReconTipe.outstandingTransfer;
    final keteranganController = TextEditingController();
    var jumlah = 0.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Item Penyesuaian'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tipe,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Jenis',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: BankReconTipe.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => tipe = v!),
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
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );

    if (result != true || jumlah <= 0) return;
    final saved = await DatabaseHelper.instance.insertBankReconciliationItem(BankReconciliationItem(
      reconciliationId: _saved!.id!,
      tipe: tipe,
      keterangan: keteranganController.text.trim(),
      jumlah: jumlah,
    ));
    setState(() => _items = [..._items, saved]);
  }

  Future<void> _deleteItem(BankReconciliationItem item) async {
    await DatabaseHelper.instance.deleteBankReconciliationItem(item.id!);
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
  }

  Future<void> _reloadItemsOnly() async {
    if (_saved?.id == null) return;
    final items = await DatabaseHelper.instance.getBankReconciliationItems(_saved!.id!);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _postItem(BankReconciliationItem item) async {
    final akun = findAccount(widget.akunKode);
    final akunNama = akun?.nama ?? widget.akunKode;
    final isCharge = item.tipe == BankReconTipe.bankCharge;
    final akunDebit = isCharge ? '61.12' : widget.akunKode;
    final akunKredit = isCharge ? widget.akunKode : '40.4';
    final defaultKeterangan = isCharge
        ? 'Biaya Bank $akunNama belum tercatat'
        : 'Bunga Bank $akunNama belum tercatat';

    final posted = await JournalService.instance.postPenyesuaian(
      tanggal: widget.tanggalCutoff,
      keterangan: item.keterangan.isEmpty ? defaultKeterangan : item.keterangan,
      jumlah: item.jumlah,
      akunDebit: akunDebit,
      akunKredit: akunKredit,
    );
    final updated = item.copyWith(posted: true, journalEntryId: posted.id);
    await DatabaseHelper.instance.updateBankReconciliationItem(updated);
    await _reloadItemsOnly();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sudah diposting ke Jurnal Penyesuaian. Saldo Buku akan ter-update.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final akun = findAccount(widget.akunKode);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(akun?.nama ?? widget.akunKode)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = buildBankReconSummary(
      saldoBuku: _saldoBuku,
      saldoRekeningKoran: _saldoRekeningKoran,
      items: _items,
    );
    final reconBalanceColor =
        summary.balanced ? context.semanticColors.success : Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(akun?.nama ?? widget.akunKode),
        actions: [
          IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Simpan', onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            title: 'Info Rekonsiliasi',
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tanggal Cutoff: ${_dateFmt.format(widget.tanggalCutoff)}'),
                const SizedBox(height: 12),
                MoneyDisplayRow(label: 'Saldo Buku (GL)', value: _saldoBuku, bold: true),
                const SizedBox(height: 12),
                MoneyField(
                  label: 'Saldo Rekening Koran',
                  value: _saldoRekeningKoran,
                  onChanged: (v) => setState(() => _saldoRekeningKoran = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _catatanController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Item Penyesuaian',
            icon: Icons.list_alt,
            trailing: IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
            child: _items.isEmpty
                ? Text('Belum ada item. Tekan + untuk menambah.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
                : Column(
                    children: [
                      for (final item in _items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item.tipe, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    color: Theme.of(context).colorScheme.error,
                                    onPressed: () => _deleteItem(item),
                                  ),
                                ],
                              ),
                              if (item.keterangan.isNotEmpty) Text(item.keterangan),
                              const SizedBox(height: 4),
                              Text(formatRupiah(item.jumlah), style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (BankReconTipe.needsPosting(item.tipe)) ...[
                                const SizedBox(height: 6),
                                if (item.posted)
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          size: 16, color: context.semanticColors.success),
                                      const SizedBox(width: 4),
                                      Text('Sudah diposting ke jurnal',
                                          style: TextStyle(
                                              fontSize: 12, color: context.semanticColors.success)),
                                    ],
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => _postItem(item),
                                    icon: const Icon(Icons.post_add, size: 16),
                                    label: const Text('Posting ke Jurnal'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          SectionCard(
            title: 'Ringkasan Rekonsiliasi',
            icon: Icons.calculate_outlined,
            child: Column(
              children: [
                MoneyDisplayRow(label: 'Saldo Buku (GL)', value: summary.saldoBuku),
                MoneyDisplayRow(label: '+ Bunga Belum Tercatat', value: summary.bungaBelumTercatat),
                MoneyDisplayRow(label: '- Biaya Bank Belum Tercatat', value: -summary.biayaBelumTercatat),
                const Divider(),
                MoneyDisplayRow(label: 'Saldo Buku Disesuaikan', value: summary.saldoBukuDisesuaikan, bold: true),
                const SizedBox(height: 16),
                MoneyDisplayRow(label: 'Saldo Rekening Koran', value: summary.saldoRekeningKoran),
                MoneyDisplayRow(label: '+ Deposit in Transit', value: summary.depositInTransit),
                MoneyDisplayRow(label: '- Outstanding Transfer/Cek', value: -summary.outstandingTransfer),
                const Divider(),
                MoneyDisplayRow(label: 'Saldo Bank Disesuaikan', value: summary.saldoBankDisesuaikan, bold: true),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: reconBalanceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(summary.balanced ? Icons.check_circle : Icons.error,
                          color: reconBalanceColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary.balanced
                              ? 'Rekonsiliasi cocok (Saldo Buku = Saldo Bank)'
                              : 'Belum cocok -- selisih ${formatRupiah(summary.selisih.abs())}. '
                                  'Cek lagi item penyesuaian atau mutasi yang belum dicatat.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: reconBalanceColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
