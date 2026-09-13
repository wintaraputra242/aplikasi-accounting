import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/barang.dart';
import '../utils/formatters.dart';
import '../widgets/quick_nav.dart';

/// Layar Master Barang: katalog global bahan baku (tidak terikat periode
/// tertentu), dipakai oleh tab Stock di tiap periode untuk Pembelian, Waste,
/// dan Stock Opname.
class MasterBarangScreen extends StatefulWidget {
  const MasterBarangScreen({super.key});

  @override
  State<MasterBarangScreen> createState() => _MasterBarangScreenState();
}

class _MasterBarangScreenState extends State<MasterBarangScreen> {
  List<BarangItem> _items = [];
  bool _loading = true;
  bool _showNonaktif = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await DatabaseHelper.instance.getAllBarangItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _showForm({BarangItem? existing}) async {
    final namaController = TextEditingController(text: existing?.nama ?? '');
    final kodeController = TextEditingController(text: existing?.kode ?? '');
    final satuanController = TextEditingController(text: existing?.satuan ?? '');
    var kategori = existing?.kategori ?? kKategoriBarang.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Tambah Barang' : 'Edit Barang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: namaController,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nama Barang', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode (opsional)',
                    hintText: 'mis. BHN-001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: satuanController,
                  decoration: const InputDecoration(
                    labelText: 'Satuan',
                    hintText: 'mis. kg, liter, pcs',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kategori,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                  items: kKategoriBarang
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => kategori = v!),
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

    if (existing == null) {
      await DatabaseHelper.instance.insertBarangItem(BarangItem(
        nama: nama,
        kode: kodeController.text.trim(),
        satuan: satuanController.text.trim(),
        kategori: kategori,
      ));
    } else {
      await DatabaseHelper.instance.updateBarangItem(existing.copyWith(
        nama: nama,
        kode: kodeController.text.trim(),
        satuan: satuanController.text.trim(),
        kategori: kategori,
      ));
    }
    await _load();
  }

  Future<void> _toggleAktif(BarangItem item) async {
    await DatabaseHelper.instance.updateBarangItem(item.copyWith(aktif: !item.aktif));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showNonaktif ? _items : _items.where((b) => b.aktif).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Barang'),
        actions: [
          IconButton(
            icon: Icon(_showNonaktif ? Icons.visibility_off : Icons.visibility),
            tooltip: _showNonaktif ? 'Sembunyikan Nonaktif' : 'Tampilkan Nonaktif',
            onPressed: () => setState(() => _showNonaktif = !_showNonaktif),
          ),
          const QuickNavButton(current: QuickNavTarget.masterBarang),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? const Center(child: Text('Belum ada barang. Tekan tombol + untuk menambah.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final b = visible[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          b.nama,
                          style: TextStyle(
                            decoration: b.aktif ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${b.kategori} • ${b.satuan.isEmpty ? '-' : b.satuan}'
                          '${b.kode.isNotEmpty ? ' • ${b.kode}' : ''}\n'
                          'Harga rata-rata: ${formatRupiah(b.hargaRataRata)}',
                        ),
                        isThreeLine: true,
                        onTap: () => _showForm(existing: b),
                        trailing: IconButton(
                          icon: Icon(
                            b.aktif ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          tooltip: b.aktif ? 'Nonaktifkan' : 'Aktifkan',
                          onPressed: () => _toggleAktif(b),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Barang'),
      ),
    );
  }
}
