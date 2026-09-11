import 'business_profile.dart';
import 'fixed_asset.dart';
import 'period.dart';

/// Bangun Laporan Posisi Keuangan (Balance Sheet) per akhir periode
/// [current]: ASSETS = LIABILITIES + EQUITY.
///
/// Aplikasi ini tidak (belum) punya buku besar double-entry sungguhan --
/// akun-akun Kas/Bank, Piutang, Hutang, Modal & Prive diisi manual tiap
/// periode sebagai SALDO AKHIR (kecuali Modal Disetor/Prive yang diisi
/// sebagai nilai PERIODE INI, lalu diakumulasi lintas periode di sini). Jadi
/// laporan ini bukan "otomatis balance" seperti buku besar sungguhan --
/// [selisih] SENGAJA ditampilkan supaya pengguna tahu kalau ada saldo yang
/// belum konsisten/belum lengkap diisi, bukan disembunyikan.

/// Satu baris tampilan pada laporan (nama akun + nominal).
class LaporanRow {
  final String label;
  final double value;

  const LaporanRow(this.label, this.value);
}

class PosisiKeuanganData {
  final List<LaporanRow> asetLancar;
  final double totalAsetLancar;

  final List<LaporanRow> asetTetap;
  final double totalHargaPerolehanAsetTetap;
  final double totalAkumulasiPenyusutan;
  final double totalAsetTetap; // nilai buku (NBV)

  final double totalAset;

  final List<LaporanRow> liabilitas;
  final double totalLiabilitas;

  final List<LaporanRow> ekuitas;
  final double totalEkuitas;

  final double totalLiabilitasEkuitas;

  /// totalAset - totalLiabilitasEkuitas. Idealnya 0 -- kalau tidak, berarti
  /// ada saldo yang belum diisi/belum konsisten dan perlu ditelusuri.
  final double selisih;

  const PosisiKeuanganData({
    required this.asetLancar,
    required this.totalAsetLancar,
    required this.asetTetap,
    required this.totalHargaPerolehanAsetTetap,
    required this.totalAkumulasiPenyusutan,
    required this.totalAsetTetap,
    required this.totalAset,
    required this.liabilitas,
    required this.totalLiabilitas,
    required this.ekuitas,
    required this.totalEkuitas,
    required this.totalLiabilitasEkuitas,
    required this.selisih,
  });
}

/// Ambil semua periode dari [allPeriods] yang tanggal mulainya sebelum atau
/// sama dengan [current] (berdasar id kalau start_date sama persis), lalu
/// urutkan dari yang paling awal. [allPeriods] biasanya hasil query DB yang
/// masih memuat salinan LAMA dari [current] (autosave di-debounce) -- salinan
/// itu disingkirkan dan diganti dengan [current] yang sedang diedit supaya
/// nilai yang dipakai selalu yang terbaru.
List<Period> periodsUpToAndIncluding(List<Period> allPeriods, Period current) {
  final result = <Period>[
    for (final p in allPeriods)
      if (p.id != current.id) p,
    current,
  ];
  result.sort((a, b) {
    final byDate = a.startDate.compareTo(b.startDate);
    if (byDate != 0) return byDate;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  });
  return result;
}

PosisiKeuanganData buildPosisiKeuangan({
  required Period current,
  required List<Period> allPeriods,
  required List<FixedAssetItem> fixedAssets,
  required BusinessProfile profile,
}) {
  final asOf = current.endDate;

  // --- Aset Lancar ---
  final asetLancar = <LaporanRow>[
    for (final item in current.kasBankItems)
      LaporanRow(item.label.isEmpty ? 'Kas/Bank' : item.label, item.value),
    LaporanRow('Piutang Usaha', current.piutangUsaha),
    LaporanRow('Persediaan', current.persediaanAkhir),
    LaporanRow('Beban Dibayar Dimuka', current.bebanDibayarDimuka),
    for (final item in current.customCurrentAssetItems)
      LaporanRow(item.label.isEmpty ? 'Aset Lancar Lainnya' : item.label, item.value),
  ];
  final totalAsetLancar = asetLancar.fold(0.0, (a, r) => a + r.value);

  // --- Aset Tetap (dari Fixed Asset Register, per kategori, nilai buku) ---
  final onBooks = fixedAssets.where((a) => a.onBalanceSheetAt(asOf)).toList();
  final asetTetap = <LaporanRow>[];
  var totalHargaPerolehan = 0.0;
  var totalAkumulasi = 0.0;
  for (final kategori in kKategoriAset) {
    final items = onBooks.where((a) => a.kategori == kategori);
    final nbv = items.fold(0.0, (a, x) => a + x.nilaiBuku(asOf));
    totalHargaPerolehan += items.fold(0.0, (a, x) => a + x.hargaPerolehan);
    totalAkumulasi += items.fold(0.0, (a, x) => a + x.akumulasiPenyusutan(asOf));
    if (nbv != 0) asetTetap.add(LaporanRow(kategori, nbv));
  }
  final totalAsetTetap = totalHargaPerolehan - totalAkumulasi;

  final totalAset = totalAsetLancar + totalAsetTetap;

  // --- Liabilitas ---
  final totalHutangLainLain =
      current.hutangLainLain + current.customLiabilityItems.fold(0.0, (a, i) => a + i.value);
  final liabilitas = <LaporanRow>[
    LaporanRow('Hutang Usaha (Supplier)', current.hutangUsaha),
    LaporanRow('Hutang Gaji Karyawan', current.hutangGajiKaryawan),
    LaporanRow('Hutang PB1', current.hutangPb1),
    LaporanRow('Hutang PPh 21', current.hutangPph21),
    LaporanRow('Hutang PPh 23', current.hutangPph23),
    LaporanRow('Hutang Pajak Badan', current.hutangPajakBadan),
    LaporanRow('Hutang Service Charge', current.hutangServiceCharge),
    LaporanRow('Hutang Lain-lain', totalHutangLainLain),
    LaporanRow('Pendapatan Diterima Dimuka', current.pendapatanDiterimaDimuka),
    LaporanRow('Pinjaman', current.pinjaman),
  ];
  final totalLiabilitas = liabilitas.fold(0.0, (a, r) => a + r.value);

  // --- Ekuitas ---
  final ordered = periodsUpToAndIncluding(allPeriods, current);
  final currentYear = current.startDate.year;

  final modalDisetorKumulatif =
      ordered.fold(0.0, (a, p) => a + p.modalDisetorPeriodeIni);
  final priveKumulatif = ordered.fold(0.0, (a, p) => a + p.privePeriodeIni);
  final labaTahunLalu = ordered
      .where((p) => p.startDate.year < currentYear)
      .fold(0.0, (a, p) => a + p.labaBersih);
  final labaTahunBerjalan = ordered
      .where((p) => p.startDate.year == currentYear)
      .fold(0.0, (a, p) => a + p.labaBersih);

  final ekuitas = <LaporanRow>[
    LaporanRow('Modal Disetor (Awal + Setoran s/d periode ini)',
        profile.modalAwalUsaha + modalDisetorKumulatif),
    LaporanRow('Laba Ditahan (Tahun-tahun Lalu)', labaTahunLalu),
    LaporanRow('Laba Tahun Berjalan (s/d periode ini)', labaTahunBerjalan),
    LaporanRow('Prive / Pengambilan Owner (s/d periode ini)', -priveKumulatif),
  ];
  final totalEkuitas = ekuitas.fold(0.0, (a, r) => a + r.value);

  final totalLiabilitasEkuitas = totalLiabilitas + totalEkuitas;

  return PosisiKeuanganData(
    asetLancar: asetLancar,
    totalAsetLancar: totalAsetLancar,
    asetTetap: asetTetap,
    totalHargaPerolehanAsetTetap: totalHargaPerolehan,
    totalAkumulasiPenyusutan: totalAkumulasi,
    totalAsetTetap: totalAsetTetap,
    totalAset: totalAset,
    liabilitas: liabilitas,
    totalLiabilitas: totalLiabilitas,
    ekuitas: ekuitas,
    totalEkuitas: totalEkuitas,
    totalLiabilitasEkuitas: totalLiabilitasEkuitas,
    selisih: totalAset - totalLiabilitasEkuitas,
  );
}
