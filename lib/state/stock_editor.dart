import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/barang.dart';
import 'period_editor.dart';

/// State untuk modul Stock pada satu periode: Master Barang (katalog
/// global, dimuat sekali), Pembelian & Waste per barang pada periode ini,
/// dan Stock Opname (stok fisik) periode ini.
///
/// Beda dari [PeriodEditor], perubahan di sini langsung ditulis ke database
/// tiap kali dipanggil (tidak di-debounce) karena bentuknya tambah/hapus
/// baris atau input per baris, bukan ketikan yang berubah tiap huruf.
class StockEditor extends ChangeNotifier {
  final int periodId;
  bool isLoading = true;

  List<BarangItem> _barangItems = [];
  List<PembelianItem> _pembelianItems = [];
  List<WasteItem> _wasteItems = [];
  List<StockOpnameRow> _opnameRows = [];

  StockEditor(this.periodId) {
    _load();
  }

  List<BarangItem> get barangAktif => _barangItems.where((b) => b.aktif).toList();
  List<PembelianItem> get pembelianItems => _pembelianItems;
  List<WasteItem> get wasteItems => _wasteItems;

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final barang = await db.getAllBarangItems();
    final pembelian = await db.getPembelianItemsByPeriod(periodId);
    final waste = await db.getWasteItemsByPeriod(periodId);
    final opnameSaved = await db.getStockOpnameByPeriod(periodId);

    // Barang aktif yang belum ada baris opname-nya di periode ini diisi
    // baris default (belum tersimpan, id null): stok awal diambil dari
    // stok fisik periode sebelumnya kalau ada, else 0.
    final opnameByBarang = {for (final o in opnameSaved) o.barangId: o};
    final opname = <StockOpnameRow>[];
    for (final b in barang.where((b) => b.aktif)) {
      final existing = opnameByBarang[b.id];
      if (existing != null) {
        opname.add(existing);
      } else {
        final prevStok = await db.getPreviousStokFisik(periodId, b.id!);
        opname.add(StockOpnameRow(periodId: periodId, barangId: b.id!, stokAwal: prevStok));
      }
    }

    _barangItems = barang;
    _pembelianItems = pembelian;
    _wasteItems = waste;
    _opnameRows = opname;
    isLoading = false;
    notifyListeners();
  }

  BarangItem? barangById(int id) {
    for (final b in _barangItems) {
      if (b.id == id) return b;
    }
    return null;
  }

  StockOpnameRow opnameForBarang(int barangId) {
    return _opnameRows.firstWhere(
      (o) => o.barangId == barangId,
      orElse: () => StockOpnameRow(periodId: periodId, barangId: barangId),
    );
  }

  double totalPembelianQty(int barangId) =>
      _pembelianItems.where((p) => p.barangId == barangId).fold(0.0, (a, p) => a + p.qty);

  double totalWasteQty(int barangId) =>
      _wasteItems.where((w) => w.barangId == barangId).fold(0.0, (a, w) => a + w.qty);

  /// Stok Sistem = Stok Awal + Pembelian - Waste (periode berjalan).
  double stokSistem(int barangId) {
    final o = opnameForBarang(barangId);
    return o.stokAwal + totalPembelianQty(barangId) - totalWasteQty(barangId);
  }

  /// Selisih = Stok Fisik - Stok Sistem.
  double selisih(int barangId) => opnameForBarang(barangId).stokFisik - stokSistem(barangId);

  double nilaiPersediaan(int barangId) {
    final o = opnameForBarang(barangId);
    final b = barangById(barangId);
    return o.stokFisik * (b?.hargaRataRata ?? 0);
  }

  double get totalNilaiPersediaan =>
      barangAktif.fold(0.0, (a, b) => a + nilaiPersediaan(b.id!));

  double totalNilaiPersediaanKategori(String kategori) => barangAktif
      .where((b) => b.kategori == kategori)
      .fold(0.0, (a, b) => a + nilaiPersediaan(b.id!));

  double totalPembelianRupiahKategori(String kategori) {
    var total = 0.0;
    for (final p in _pembelianItems) {
      final b = barangById(p.barangId);
      if (b != null && b.kategori == kategori) total += p.total;
    }
    return total;
  }

  double get totalWasteRupiah => _wasteItems.fold(0.0, (a, w) => a + w.nilaiRupiah);

  // --- Pembelian ---

  Future<void> addPembelian(int barangId) async {
    final item = PembelianItem(periodId: periodId, barangId: barangId, tanggal: DateTime.now());
    final saved = await DatabaseHelper.instance.insertPembelianItem(item);
    _pembelianItems = [..._pembelianItems, saved];
    await _reloadHargaRataRata();
  }

  Future<void> updatePembelian(PembelianItem item) async {
    await DatabaseHelper.instance.updatePembelianItem(item);
    _pembelianItems = [for (final p in _pembelianItems) p.id == item.id ? item : p];
    await _reloadHargaRataRata();
  }

  Future<void> removePembelian(PembelianItem item) async {
    await DatabaseHelper.instance.deletePembelianItem(item.id!, item.barangId);
    _pembelianItems = _pembelianItems.where((p) => p.id != item.id).toList();
    await _reloadHargaRataRata();
  }

  /// Harga rata-rata barang dihitung ulang di DB tiap pembelian
  /// ditambah/diubah/dihapus (lihat `DatabaseHelper._recalcHargaRataRata`),
  /// jadi katalog barang lokal perlu dimuat ulang supaya UI ikut ter-update.
  Future<void> _reloadHargaRataRata() async {
    _barangItems = await DatabaseHelper.instance.getAllBarangItems();
    notifyListeners();
  }

  // --- Waste ---

  Future<void> addWaste(int barangId) async {
    final item = WasteItem(periodId: periodId, barangId: barangId, tanggal: DateTime.now());
    final saved = await DatabaseHelper.instance.insertWasteItem(item);
    _wasteItems = [..._wasteItems, saved];
    notifyListeners();
  }

  Future<void> updateWaste(WasteItem item) async {
    await DatabaseHelper.instance.updateWasteItem(item);
    _wasteItems = [for (final w in _wasteItems) w.id == item.id ? item : w];
    notifyListeners();
  }

  Future<void> removeWaste(WasteItem item) async {
    await DatabaseHelper.instance.deleteWasteItem(item.id!);
    _wasteItems = _wasteItems.where((w) => w.id != item.id).toList();
    notifyListeners();
  }

  // --- Stock Opname ---

  void _upsertLocalOpname(StockOpnameRow saved) {
    final idx = _opnameRows.indexWhere((o) => o.barangId == saved.barangId);
    if (idx >= 0) {
      _opnameRows[idx] = saved;
    } else {
      _opnameRows.add(saved);
    }
  }

  Future<void> setStokAwal(int barangId, double value) async {
    final updated = opnameForBarang(barangId).copyWith(stokAwal: value);
    final saved = await DatabaseHelper.instance.upsertStockOpname(updated);
    _upsertLocalOpname(saved);
    notifyListeners();
  }

  Future<void> setStokFisik(int barangId, double value) async {
    final updated = opnameForBarang(barangId).copyWith(stokFisik: value);
    final saved = await DatabaseHelper.instance.upsertStockOpname(updated);
    _upsertLocalOpname(saved);
    notifyListeners();
  }

  /// Timpa Persediaan Awal/Akhir, Total Pembelian Bahan Baku (tab Pembelian)
  /// dan Beban Waste (tab Beban) di [periodEditor] dengan hasil perhitungan
  /// dari data Stock ini. Ini aksi manual (tombol), bukan otomatis, sesuai
  /// model integrasi "berdampingan/opsional" yang sudah disepakati.
  void syncToPeriod(PeriodEditor periodEditor) {
    final saldoAwal = barangAktif.fold(0.0, (a, b) {
      final o = opnameForBarang(b.id!);
      return a + o.stokAwal * b.hargaRataRata;
    });
    final totalPembelian = _pembelianItems.fold(0.0, (a, p) => a + p.total);

    periodEditor.setSaldoAwal(saldoAwal);
    periodEditor.setPersediaanAkhir(totalNilaiPersediaan);
    periodEditor.setTotalPembelianBahanBaku(totalPembelian);
    periodEditor.setBebanWasteBahanBaku(totalWasteRupiah);
  }
}
