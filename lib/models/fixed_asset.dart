/// Model untuk Fixed Asset Register: katalog aset tetap global (tidak
/// terikat periode tertentu) plus perhitungan penyusutan garis lurus.
///
/// Beda dengan modul Stock, Fixed Asset Register TIDAK butuh tabel anak per
/// periode -- penyusutan murni fungsi dari tanggal (tanggal beli, umur,
/// tanggal nonaktif kalau ada), jadi bisa dihitung ulang kapan saja "per
/// tanggal X" tanpa perlu snapshot tersimpan. Ini justru lebih akurat dari
/// modul Stock untuk periode LAMA yang dibuka ulang (lihat catatan di
/// `lib/models/barang.dart`), karena tidak ada nilai "terkini" yang dipakai
/// mundur ke masa lalu.
library;

/// Kategori aset -- menentukan field Beban Penyusutan mana di [Period] yang
/// diisi (lihat `AsetTab.syncToPeriod` / pemetaan di `aset_tab.dart`).
const kKategoriAset = ['Bar', 'Kitchen', 'Furniture Area', 'Office'];

/// Alasan baku saat aset dinonaktifkan dari checklist penutupan periode.
const kAlasanNonaktifAset = ['Rusak', 'Dijual', 'Hilang', 'Tidak Dipakai', 'Lainnya'];

String _dateToIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateFromIso(String s) => DateTime.parse(s);

/// Hitung jumlah bulan penuh yang sudah berlalu dari [from] ke [to] (0 kalau
/// [to] lebih awal dari [from]). Dipakai untuk Akumulasi Penyusutan.
int _fullMonthsBetween(DateTime from, DateTime to) {
  if (to.isBefore(from)) return 0;
  var months = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day < from.day) months -= 1;
  return months < 0 ? 0 : months;
}

class FixedAssetItem {
  final int? id;
  final String kode;
  final String nama;
  final String kategori; // salah satu dari kKategoriAset
  final String lokasi; // bebas teks, opsional (mis. "Bar", "Cashier")
  final DateTime tanggalBeli;
  final double hargaPerolehan;
  final int umurTahun;
  final bool aktif;
  final String alasanNonaktif;
  final DateTime? tanggalNonaktif;

  const FixedAssetItem({
    this.id,
    this.kode = '',
    required this.nama,
    this.kategori = 'Kitchen',
    this.lokasi = '',
    required this.tanggalBeli,
    this.hargaPerolehan = 0,
    this.umurTahun = 1,
    this.aktif = true,
    this.alasanNonaktif = '',
    this.tanggalNonaktif,
  });

  /// Harga Perolehan ÷ Umur (tahun) ÷ 12.
  double get penyusutanPerBulan => umurTahun <= 0 ? 0 : hargaPerolehan / umurTahun / 12;

  /// Tanggal efektif berhenti menyusut: [tanggalNonaktif] kalau aset sudah
  /// dinonaktifkan, else null (masih terus menyusut sampai [asOf]).
  DateTime _effectiveAsOf(DateTime asOf) {
    final nonaktif = tanggalNonaktif;
    if (nonaktif != null && nonaktif.isBefore(asOf)) return nonaktif;
    return asOf;
  }

  /// Akumulasi Penyusutan per tanggal [asOf], dibatasi maksimal Harga
  /// Perolehan (aset yang sudah lunas disusutkan tidak terus bertambah).
  double akumulasiPenyusutan(DateTime asOf) {
    final months = _fullMonthsBetween(tanggalBeli, _effectiveAsOf(asOf));
    final akumulasi = months * penyusutanPerBulan;
    return akumulasi > hargaPerolehan ? hargaPerolehan : akumulasi;
  }

  /// Nilai Buku = Harga Perolehan - Akumulasi Penyusutan.
  double nilaiBuku(DateTime asOf) => hargaPerolehan - akumulasiPenyusutan(asOf);

  /// Apakah aset ini "aktif" (ikut disusutkan) pada rentang tanggal
  /// [periodStart]-[periodEnd] -- dipakai untuk hitung Beban Penyusutan satu
  /// periode (satu bulan penuh per aset yang aktif, tanpa prorata harian).
  bool aktifPadaPeriode(DateTime periodStart, DateTime periodEnd) {
    if (tanggalBeli.isAfter(periodEnd)) return false;
    final nonaktif = tanggalNonaktif;
    if (nonaktif != null && nonaktif.isBefore(periodStart)) return false;
    return true;
  }

  /// Apakah aset ini masih tercatat di Neraca (Laporan Posisi Keuangan) per
  /// tanggal [asOf] -- beda dengan [aktifPadaPeriode] (yang menjawab "apakah
  /// aset ini menyusut pada periode X"), ini menjawab "apakah aset ini masih
  /// dimiliki pada tanggal X". Aset yang sudah dinonaktifkan (dijual/rusak/
  /// hilang) SEBELUM ATAU PADA tanggal [asOf] sudah tidak lagi masuk Neraca.
  bool onBalanceSheetAt(DateTime asOf) {
    if (tanggalBeli.isAfter(asOf)) return false;
    final nonaktif = tanggalNonaktif;
    if (nonaktif != null && !nonaktif.isAfter(asOf)) return false;
    return true;
  }

  FixedAssetItem copyWith({
    String? kode,
    String? nama,
    String? kategori,
    String? lokasi,
    DateTime? tanggalBeli,
    double? hargaPerolehan,
    int? umurTahun,
    bool? aktif,
    String? alasanNonaktif,
    DateTime? tanggalNonaktif,
  }) {
    return FixedAssetItem(
      id: id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      lokasi: lokasi ?? this.lokasi,
      tanggalBeli: tanggalBeli ?? this.tanggalBeli,
      hargaPerolehan: hargaPerolehan ?? this.hargaPerolehan,
      umurTahun: umurTahun ?? this.umurTahun,
      aktif: aktif ?? this.aktif,
      alasanNonaktif: alasanNonaktif ?? this.alasanNonaktif,
      tanggalNonaktif: tanggalNonaktif ?? this.tanggalNonaktif,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'kategori': kategori,
        'lokasi': lokasi,
        'tanggal_beli': _dateToIso(tanggalBeli),
        'harga_perolehan': hargaPerolehan,
        'umur_tahun': umurTahun,
        'aktif': aktif ? 1 : 0,
        'alasan_nonaktif': alasanNonaktif,
        'tanggal_nonaktif': tanggalNonaktif == null ? null : _dateToIso(tanggalNonaktif!),
      };

  factory FixedAssetItem.fromMap(Map<String, Object?> map) => FixedAssetItem(
        id: map['id'] as int?,
        kode: map['kode'] as String? ?? '',
        nama: map['nama'] as String? ?? '',
        kategori: map['kategori'] as String? ?? 'Kitchen',
        lokasi: map['lokasi'] as String? ?? '',
        tanggalBeli: _dateFromIso(map['tanggal_beli'] as String),
        hargaPerolehan: (map['harga_perolehan'] as num?)?.toDouble() ?? 0,
        umurTahun: (map['umur_tahun'] as num?)?.toInt() ?? 1,
        aktif: ((map['aktif'] as int?) ?? 1) != 0,
        alasanNonaktif: map['alasan_nonaktif'] as String? ?? '',
        tanggalNonaktif: (map['tanggal_nonaktif'] as String?) == null
            ? null
            : _dateFromIso(map['tanggal_nonaktif'] as String),
      );
}
