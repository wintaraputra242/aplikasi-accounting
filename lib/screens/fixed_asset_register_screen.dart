import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/fixed_asset.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/quick_nav.dart';

/// Layar Fixed Asset Register: katalog aset tetap global, dengan penyusutan
/// (Akumulasi Penyusutan, Nilai Buku) dihitung otomatis per hari ini --
/// lihat [FixedAssetItem.akumulasiPenyusutan]/[FixedAssetItem.nilaiBuku].
class FixedAssetRegisterScreen extends StatefulWidget {
  const FixedAssetRegisterScreen({super.key});

  @override
  State<FixedAssetRegisterScreen> createState() => _FixedAssetRegisterScreenState();
}

class _FixedAssetRegisterScreenState extends State<FixedAssetRegisterScreen> {
  List<FixedAssetItem> _items = [];
  bool _loading = true;
  bool _showNonaktif = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await DatabaseHelper.instance.getAllFixedAssets();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _showForm({FixedAssetItem? existing}) async {
    final namaController = TextEditingController(text: existing?.nama ?? '');
    final kodeController = TextEditingController(text: existing?.kode ?? '');
    final lokasiController = TextEditingController(text: existing?.lokasi ?? '');
    final umurController = TextEditingController(text: existing?.umurTahun.toString() ?? '');
    var kategori = existing?.kategori ?? kKategoriAset.first;
    var tanggalBeli = existing?.tanggalBeli ?? DateTime.now();
    var hargaPerolehan = existing?.hargaPerolehan ?? 0.0;
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah Aset' : 'Edit Aset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: namaController,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nama Aset', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode (opsional)',
                    hintText: 'mis. FA-BAR-001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kategori,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                  items:
                      kKategoriAset.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setDialogState(() => kategori = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lokasiController,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi (opsional)',
                    hintText: 'mis. Bar, Kitchen, Cashier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tanggalBeli,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => tanggalBeli = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text('Tanggal Beli: ${dateFmt.format(tanggalBeli)}'),
                ),
                const SizedBox(height: 12),
                MoneyField(
                  label: 'Harga Perolehan',
                  value: hargaPerolehan,
                  onChanged: (v) => hargaPerolehan = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: umurController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Umur Manfaat (tahun)',
                    hintText: 'mis. 8',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final nama = namaController.text.trim();
    if (nama.isEmpty) return;
    final umurTahun = int.tryParse(umurController.text.trim()) ?? 1;

    if (existing == null) {
      await DatabaseHelper.instance.insertFixedAsset(FixedAssetItem(
        nama: nama,
        kode: kodeController.text.trim(),
        kategori: kategori,
        lokasi: lokasiController.text.trim(),
        tanggalBeli: tanggalBeli,
        hargaPerolehan: hargaPerolehan,
        umurTahun: umurTahun < 1 ? 1 : umurTahun,
      ));
    } else {
      await DatabaseHelper.instance.updateFixedAsset(existing.copyWith(
        nama: nama,
        kode: kodeController.text.trim(),
        kategori: kategori,
        lokasi: lokasiController.text.trim(),
        tanggalBeli: tanggalBeli,
        hargaPerolehan: hargaPerolehan,
        umurTahun: umurTahun < 1 ? 1 : umurTahun,
      ));
    }
    await _load();
  }

  Future<void> _nonaktifkan(FixedAssetItem item) async {
    var alasan = kAlasanNonaktifAset.first;
    var tanggal = DateTime.now();
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Nonaktifkan "${item.nama}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Penyusutan berhenti dihitung mulai tanggal ini. Sesuai checklist '
                'penutupan periode: aset rusak/dijual/hilang/tidak dipakai lagi.',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: alasan,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Alasan', border: OutlineInputBorder()),
                items: kAlasanNonaktifAset
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setDialogState(() => alasan = v!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: tanggal,
                    firstDate: item.tanggalBeli,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialogState(() => tanggal = picked);
                },
                icon: const Icon(Icons.event),
                label: Text('Tanggal: ${dateFmt.format(tanggal)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    await DatabaseHelper.instance.updateFixedAsset(item.copyWith(
      aktif: false,
      alasanNonaktif: alasan,
      tanggalNonaktif: tanggal,
    ));
    await _load();
  }

  Future<void> _aktifkanKembali(FixedAssetItem item) async {
    await DatabaseHelper.instance.updateFixedAsset(item.copyWith(aktif: true));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showNonaktif ? _items : _items.where((a) => a.aktif).toList();
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixed Asset Register'),
        actions: [
          IconButton(
            icon: Icon(_showNonaktif ? Icons.visibility_off : Icons.visibility),
            tooltip: _showNonaktif ? 'Sembunyikan Nonaktif' : 'Tampilkan Nonaktif',
            onPressed: () => setState(() => _showNonaktif = !_showNonaktif),
          ),
          const QuickNavButton(current: QuickNavTarget.fixedAssetRegister),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? const Center(child: Text('Belum ada aset. Tekan tombol + untuk menambah.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final a = visible[i];
                    final akumulasi = a.akumulasiPenyusutan(now);
                    final nilaiBuku = a.nilaiBuku(now);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.nama,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: a.aktif ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit',
                                  onPressed: () => _showForm(existing: a),
                                ),
                                IconButton(
                                  icon: Icon(
                                    a.aktif ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  tooltip: a.aktif ? 'Nonaktifkan' : 'Aktifkan Kembali',
                                  onPressed: () =>
                                      a.aktif ? _nonaktifkan(a) : _aktifkanKembali(a),
                                ),
                              ],
                            ),
                            Text(
                              '${a.kategori}${a.lokasi.isNotEmpty ? ' • ${a.lokasi}' : ''}'
                              '${a.kode.isNotEmpty ? ' • ${a.kode}' : ''}',
                              style:
                                  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text('Tanggal Beli: ${dateFmt.format(a.tanggalBeli)}'),
                            Text('Harga Perolehan: ${formatRupiah(a.hargaPerolehan)}'),
                            Text('Umur: ${a.umurTahun} Thn • Penyusutan/Bulan: '
                                '${formatRupiah(a.penyusutanPerBulan)}'),
                            Text('Akumulasi Penyusutan: ${formatRupiah(akumulasi)}'),
                            Text(
                              'Nilai Buku: ${formatRupiah(nilaiBuku)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (!a.aktif) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Nonaktif: ${a.alasanNonaktif}'
                                '${a.tanggalNonaktif != null ? ' (${dateFmt.format(a.tanggalNonaktif!)})' : ''}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Aset'),
      ),
    );
  }
}
