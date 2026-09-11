/// Model untuk modul Stock (Master Barang, Pembelian & Waste per barang,
/// Stock Opname). Lihat `lib/state/stock_editor.dart` untuk logika
/// pemuatan & perhitungan turunannya (stok sistem, selisih, nilai
/// persediaan, rekap HPP per kategori).
///
/// Catatan desain: "Harga Rata-rata" barang TIDAK disnapshot per periode --
/// selalu dihitung ulang dari SELURUH histori pembelian barang itu (lihat
/// `DatabaseHelper._recalcHargaRataRata`) dan dipakai sebagai harga terkini
/// untuk menilai persediaan di periode manapun. Konsekuensinya: kalau harga
/// beli berubah drastis, nilai persediaan periode LAMA yang dibuka ulang
/// akan ikut memakai harga terbaru, bukan harga saat itu. Ini simplifikasi
/// yang disengaja untuk Fase 1 (dibahas & disetujui) supaya skema tetap
/// sederhana -- bisa ditingkatkan ke snapshot per periode nanti kalau memang
/// dibutuhkan.
library;

/// Dua kategori lokasi barang yang dipakai Mangana untuk memecah HPP jadi
/// Bar vs Kitchen.
const kKategoriBarang = ['Bar', 'Kitchen'];

/// Alasan baku untuk baris Waste & Adjustment.
const kAlasanWaste = ['Rusak', 'Expired', 'Salah Produksi', 'Complimentary', 'Selisih', 'Lainnya'];

String _dateToIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateFromIso(String s) => DateTime.parse(s);

/// Satu barang di Master Barang (katalog global, tidak terikat periode).
class BarangItem {
  final int? id;
  final String kode;
  final String nama;
  final String kategori; // salah satu dari kKategoriBarang
  final String satuan;
  final double hargaRataRata;
  final bool aktif;

  const BarangItem({
    this.id,
    this.kode = '',
    required this.nama,
    this.kategori = 'Kitchen',
    this.satuan = '',
    this.hargaRataRata = 0,
    this.aktif = true,
  });

  BarangItem copyWith({
    String? kode,
    String? nama,
    String? kategori,
    String? satuan,
    double? hargaRataRata,
    bool? aktif,
  }) {
    return BarangItem(
      id: id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      satuan: satuan ?? this.satuan,
      hargaRataRata: hargaRataRata ?? this.hargaRataRata,
      aktif: aktif ?? this.aktif,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'kategori': kategori,
        'satuan': satuan,
        'harga_rata_rata': hargaRataRata,
        'aktif': aktif ? 1 : 0,
      };

  factory BarangItem.fromMap(Map<String, Object?> map) => BarangItem(
        id: map['id'] as int?,
        kode: map['kode'] as String? ?? '',
        nama: map['nama'] as String? ?? '',
        kategori: map['kategori'] as String? ?? 'Kitchen',
        satuan: map['satuan'] as String? ?? '',
        hargaRataRata: (map['harga_rata_rata'] as num?)?.toDouble() ?? 0,
        aktif: ((map['aktif'] as int?) ?? 1) != 0,
      );
}

/// Satu baris pembelian barang pada satu periode.
class PembelianItem {
  final int? id;
  final int periodId;
  final int barangId;
  final DateTime tanggal;
  final double qty;
  final double hargaSatuan;
  final String keterangan;

  const PembelianItem({
    this.id,
    required this.periodId,
    required this.barangId,
    required this.tanggal,
    this.qty = 0,
    this.hargaSatuan = 0,
    this.keterangan = '',
  });

  double get total => qty * hargaSatuan;

  PembelianItem copyWith({
    DateTime? tanggal,
    double? qty,
    double? hargaSatuan,
    String? keterangan,
  }) {
    return PembelianItem(
      id: id,
      periodId: periodId,
      barangId: barangId,
      tanggal: tanggal ?? this.tanggal,
      qty: qty ?? this.qty,
      hargaSatuan: hargaSatuan ?? this.hargaSatuan,
      keterangan: keterangan ?? this.keterangan,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'period_id': periodId,
        'barang_id': barangId,
        'tanggal': _dateToIso(tanggal),
        'qty': qty,
        'harga_satuan': hargaSatuan,
        'keterangan': keterangan,
      };

  factory PembelianItem.fromMap(Map<String, Object?> map) => PembelianItem(
        id: map['id'] as int?,
        periodId: map['period_id'] as int,
        barangId: map['barang_id'] as int,
        tanggal: _dateFromIso(map['tanggal'] as String),
        qty: (map['qty'] as num?)?.toDouble() ?? 0,
        hargaSatuan: (map['harga_satuan'] as num?)?.toDouble() ?? 0,
        keterangan: map['keterangan'] as String? ?? '',
      );
}

/// Satu baris waste/adjustment barang pada satu periode. [nilaiRupiah]
/// diisi terpisah dari [qty] (bukan otomatis qty x harga) supaya pengguna
/// bisa menyesuaikan sendiri kalau nilai kerugiannya beda dari harga beli
/// standar (mis. barang complimentary yang harga jualnya dipakai, bukan
/// harga beli).
class WasteItem {
  final int? id;
  final int periodId;
  final int barangId;
  final DateTime tanggal;
  final double qty;
  final String alasan;
  final double nilaiRupiah;
  final String keterangan;

  const WasteItem({
    this.id,
    required this.periodId,
    required this.barangId,
    required this.tanggal,
    this.qty = 0,
    this.alasan = 'Rusak',
    this.nilaiRupiah = 0,
    this.keterangan = '',
  });

  WasteItem copyWith({
    DateTime? tanggal,
    double? qty,
    String? alasan,
    double? nilaiRupiah,
    String? keterangan,
  }) {
    return WasteItem(
      id: id,
      periodId: periodId,
      barangId: barangId,
      tanggal: tanggal ?? this.tanggal,
      qty: qty ?? this.qty,
      alasan: alasan ?? this.alasan,
      nilaiRupiah: nilaiRupiah ?? this.nilaiRupiah,
      keterangan: keterangan ?? this.keterangan,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'period_id': periodId,
        'barang_id': barangId,
        'tanggal': _dateToIso(tanggal),
        'qty': qty,
        'alasan': alasan,
        'nilai_rupiah': nilaiRupiah,
        'keterangan': keterangan,
      };

  factory WasteItem.fromMap(Map<String, Object?> map) => WasteItem(
        id: map['id'] as int?,
        periodId: map['period_id'] as int,
        barangId: map['barang_id'] as int,
        tanggal: _dateFromIso(map['tanggal'] as String),
        qty: (map['qty'] as num?)?.toDouble() ?? 0,
        alasan: map['alasan'] as String? ?? 'Rusak',
        nilaiRupiah: (map['nilai_rupiah'] as num?)?.toDouble() ?? 0,
        keterangan: map['keterangan'] as String? ?? '',
      );
}

/// Satu baris Stock Opname: stok fisik hasil hitung real per barang pada
/// satu periode. Stok Sistem, Selisih, dan Nilai Persediaan sengaja TIDAK
/// disimpan di sini -- selalu dihitung ulang di [StockEditor] dari data
/// Pembelian/Waste/harga terkini, supaya tidak ada dua sumber kebenaran
/// yang bisa saling tidak sinkron.
class StockOpnameRow {
  final int? id;
  final int periodId;
  final int barangId;
  final double stokAwal;
  final double stokFisik;

  const StockOpnameRow({
    this.id,
    required this.periodId,
    required this.barangId,
    this.stokAwal = 0,
    this.stokFisik = 0,
  });

  StockOpnameRow copyWith({double? stokAwal, double? stokFisik}) {
    return StockOpnameRow(
      id: id,
      periodId: periodId,
      barangId: barangId,
      stokAwal: stokAwal ?? this.stokAwal,
      stokFisik: stokFisik ?? this.stokFisik,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'period_id': periodId,
        'barang_id': barangId,
        'stok_awal': stokAwal,
        'stok_fisik': stokFisik,
      };

  factory StockOpnameRow.fromMap(Map<String, Object?> map) => StockOpnameRow(
        id: map['id'] as int?,
        periodId: map['period_id'] as int,
        barangId: map['barang_id'] as int,
        stokAwal: (map['stok_awal'] as num?)?.toDouble() ?? 0,
        stokFisik: (map['stok_fisik'] as num?)?.toDouble() ?? 0,
      );
}
