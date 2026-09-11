import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/barang.dart';
import '../../state/period_editor.dart';
import '../../state/stock_editor.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../master_barang_screen.dart';

/// Tab Stock: Pembelian & Waste per barang, Stock Opname, dan Rekap HPP
/// Bar vs Kitchen. Fase 1 dari modul manajemen stok Mangana.
class StockTab extends StatelessWidget {
  const StockTab({super.key});

  Future<void> _addPembelian(BuildContext context, StockEditor stock) async {
    final barang = await _pickBarang(context, stock.barangAktif);
    if (barang != null) await stock.addPembelian(barang.id!);
  }

  Future<void> _addWaste(BuildContext context, StockEditor stock) async {
    final barang = await _pickBarang(context, stock.barangAktif);
    if (barang != null) await stock.addWaste(barang.id!);
  }

  Future<void> _sync(BuildContext context, StockEditor stock) async {
    final editor = context.read<PeriodEditor>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update ke Laporan Periode?'),
        content: const Text(
          'Persediaan Awal, Persediaan Akhir, Total Pembelian Bahan Baku (tab '
          'Pembelian), dan Beban Waste (tab Beban) akan ditimpa dengan hasil '
          'perhitungan dari data Stock ini. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    if (confirm != true) return;
    stock.syncToPeriod(editor);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan periode berhasil di-update dari data Stock.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockEditor>();

    if (stock.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stock.barangAktif.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Belum ada barang di Master Barang.\nTambahkan dulu daftar bahan baku di sana.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MasterBarangScreen()),
                  );
                },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Buka Master Barang'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Master Barang',
          icon: Icons.inventory_2,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MasterBarangScreen()),
              );
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('Kelola Daftar Barang'),
          ),
        ),
        SectionCard(
          title: 'Pembelian Bahan Baku (per Barang)',
          icon: Icons.shopping_basket,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in stock.pembelianItems)
                _PembelianRow(
                  key: ValueKey('beli-${item.id}'),
                  item: item,
                  barang: stock.barangById(item.barangId),
                  onChanged: stock.updatePembelian,
                  onRemove: () => stock.removePembelian(item),
                ),
              OutlinedButton.icon(
                onPressed: () => _addPembelian(context, stock),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Pembelian'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Waste & Adjustment',
          icon: Icons.delete_sweep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in stock.wasteItems)
                _WasteRow(
                  key: ValueKey('waste-${item.id}'),
                  item: item,
                  barang: stock.barangById(item.barangId),
                  onChanged: stock.updateWaste,
                  onRemove: () => stock.removeWaste(item),
                ),
              OutlinedButton.icon(
                onPressed: () => _addWaste(context, stock),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Waste'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Stock Opname',
          icon: Icons.fact_check,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in stock.barangAktif)
                _OpnameRow(key: ValueKey('opname-${b.id}'), barang: b, stock: stock),
            ],
          ),
        ),
        _RekapHppCard(stock: stock),
        SectionCard(
          title: 'Sinkronkan ke Laporan Periode',
          icon: Icons.sync,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kalau Stock Opname periode ini sudah lengkap diisi, tekan tombol '
                'di bawah untuk mengisi otomatis Persediaan Awal/Akhir & Total '
                'Pembelian di tab Pembelian, dan Beban Waste di tab Beban.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _sync(context, stock),
                icon: const Icon(Icons.sync),
                label: const Text('Update ke Laporan Periode'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog pilih barang (dengan pencarian sederhana), dipakai tombol "Tambah
/// Pembelian" & "Tambah Waste".
Future<BarangItem?> _pickBarang(BuildContext context, List<BarangItem> options) async {
  if (options.isEmpty) return null;
  var query = '';
  return showDialog<BarangItem>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final filtered = query.isEmpty
            ? options
            : options.where((b) => b.nama.toLowerCase().contains(query.toLowerCase())).toList();
        return AlertDialog(
          title: const Text('Pilih Barang'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cari barang',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: filtered.isEmpty
                      ? const Center(child: Text('Tidak ditemukan'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final b = filtered[i];
                            return ListTile(
                              title: Text(b.nama),
                              subtitle: Text('${b.kategori} • ${b.satuan}'),
                              onTap: () => Navigator.pop(ctx, b),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ],
        );
      },
    ),
  );
}

String _fmtQty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

class _PembelianRow extends StatefulWidget {
  final PembelianItem item;
  final BarangItem? barang;
  final ValueChanged<PembelianItem> onChanged;
  final VoidCallback onRemove;

  const _PembelianRow({
    super.key,
    required this.item,
    required this.barang,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PembelianRow> createState() => _PembelianRowState();
}

class _PembelianRowState extends State<_PembelianRow> {
  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.item.tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) widget.onChanged(widget.item.copyWith(tanggal: picked));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.barang?.nama ?? '(barang tidak ditemukan)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.event, size: 16),
                label: Text(dateFmt.format(widget.item.tanggal), style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QtyField(
                  label: 'Qty',
                  value: widget.item.qty,
                  suffixText: widget.barang?.satuan,
                  onChanged: (v) => widget.onChanged(widget.item.copyWith(qty: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MoneyField(
                  label: 'Harga Satuan',
                  value: widget.item.hargaSatuan,
                  onChanged: (v) => widget.onChanged(widget.item.copyWith(hargaSatuan: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${formatRupiah(widget.item.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteRow extends StatefulWidget {
  final WasteItem item;
  final BarangItem? barang;
  final ValueChanged<WasteItem> onChanged;
  final VoidCallback onRemove;

  const _WasteRow({
    super.key,
    required this.item,
    required this.barang,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_WasteRow> createState() => _WasteRowState();
}

class _WasteRowState extends State<_WasteRow> {
  late final TextEditingController _keteranganController;

  @override
  void initState() {
    super.initState();
    _keteranganController = TextEditingController(text: widget.item.keterangan);
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.barang?.nama ?? '(barang tidak ditemukan)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QtyField(
                  label: 'Qty',
                  value: widget.item.qty,
                  suffixText: widget.barang?.satuan,
                  onChanged: (v) => widget.onChanged(widget.item.copyWith(qty: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      kAlasanWaste.contains(widget.item.alasan) ? widget.item.alasan : kAlasanWaste.first,
                  decoration: const InputDecoration(
                    labelText: 'Alasan',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: kAlasanWaste.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) {
                    if (v != null) widget.onChanged(widget.item.copyWith(alasan: v));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MoneyField(
            label: 'Nilai Kerugian',
            value: widget.item.nilaiRupiah,
            onChanged: (v) => widget.onChanged(widget.item.copyWith(nilaiRupiah: v)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _keteranganController,
            decoration: const InputDecoration(
              labelText: 'Keterangan',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => widget.onChanged(widget.item.copyWith(keterangan: v)),
          ),
        ],
      ),
    );
  }
}

class _OpnameRow extends StatelessWidget {
  final BarangItem barang;
  final StockEditor stock;

  const _OpnameRow({super.key, required this.barang, required this.stock});

  @override
  Widget build(BuildContext context) {
    final opname = stock.opnameForBarang(barang.id!);
    final pembelian = stock.totalPembelianQty(barang.id!);
    final waste = stock.totalWasteQty(barang.id!);
    final stokSistem = stock.stokSistem(barang.id!);
    final selisih = stock.selisih(barang.id!);
    final nilai = stock.nilaiPersediaan(barang.id!);
    final selisihColor =
        selisih == 0 ? Colors.black54 : (selisih > 0 ? Colors.green.shade700 : Colors.red.shade700);

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${barang.nama} (${barang.kategori})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: Text(
                  'Harga rata-rata: ${formatRupiah(barang.hargaRataRata)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QtyField(
                  label: 'Stok Awal',
                  value: opname.stokAwal,
                  suffixText: barang.satuan,
                  onChanged: (v) => stock.setStokAwal(barang.id!, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QtyField(
                  label: 'Stok Fisik',
                  value: opname.stokFisik,
                  suffixText: barang.satuan,
                  onChanged: (v) => stock.setStokFisik(barang.id!, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '+ Pembelian: ${_fmtQty(pembelian)} ${barang.satuan}   '
            '- Waste: ${_fmtQty(waste)} ${barang.satuan}   '
            '= Stok Sistem: ${_fmtQty(stokSistem)} ${barang.satuan}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Selisih: ${selisih > 0 ? '+' : ''}${_fmtQty(selisih)} ${barang.satuan}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selisihColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Nilai Persediaan: ${formatRupiah(nilai)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RekapHppCard extends StatelessWidget {
  final StockEditor stock;

  const _RekapHppCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final rows = <String, Map<String, double>>{};
    for (final kategori in kKategoriBarang) {
      final items = stock.barangAktif.where((b) => b.kategori == kategori);
      final persediaanAwal = items.fold<double>(
        0.0,
        (a, b) => a + stock.opnameForBarang(b.id!).stokAwal * b.hargaRataRata,
      );
      final pembelian = stock.totalPembelianRupiahKategori(kategori);
      final persediaanAkhir = stock.totalNilaiPersediaanKategori(kategori);
      rows[kategori] = {
        'awal': persediaanAwal,
        'pembelian': pembelian,
        'tersedia': persediaanAwal + pembelian,
        'akhir': persediaanAkhir,
        'hpp': persediaanAwal + pembelian - persediaanAkhir,
      };
    }
    final totalAwal = rows.values.fold(0.0, (a, r) => a + r['awal']!);
    final totalPembelian = rows.values.fold(0.0, (a, r) => a + r['pembelian']!);
    final totalTersedia = rows.values.fold(0.0, (a, r) => a + r['tersedia']!);
    final totalAkhir = rows.values.fold(0.0, (a, r) => a + r['akhir']!);
    final totalHpp = rows.values.fold(0.0, (a, r) => a + r['hpp']!);

    DataRow row(String label, String key, double total, {bool bold = false}) {
      final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
      return DataRow(cells: [
        DataCell(Text(label, style: style)),
        DataCell(Text(formatRupiah(rows['Bar']![key]!), style: style)),
        DataCell(Text(formatRupiah(rows['Kitchen']![key]!), style: style)),
        DataCell(Text(formatRupiah(total), style: style)),
      ]);
    }

    return SectionCard(
      title: 'Rekap HPP per Kategori',
      icon: Icons.bar_chart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
          ),
          columns: const [
            DataColumn(label: Text('Keterangan')),
            DataColumn(label: Text('Bar'), numeric: true),
            DataColumn(label: Text('Kitchen'), numeric: true),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: [
            row('Persediaan Awal', 'awal', totalAwal),
            row('Pembelian', 'pembelian', totalPembelian),
            row('Barang Tersedia', 'tersedia', totalTersedia),
            row('Persediaan Akhir', 'akhir', totalAkhir),
            row('HPP', 'hpp', totalHpp, bold: true),
          ],
        ),
      ),
    );
  }
}
