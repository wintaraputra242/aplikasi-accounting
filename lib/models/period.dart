import 'dart:convert';

import 'package:intl/intl.dart';

/// Cara periode ditentukan: berdasarkan bulan kalender penuh, atau berdasarkan
/// rentang tanggal bebas (mis. siklus tagihan 26 Jun - 25 Jul).
enum PeriodType { calendar, custom }

/// Satu akun tambahan yang ditambahkan bebas oleh pengguna (lewat tombol
/// "+ Tambah Akun" di tab Penjualan/Beban), di luar kategori baku yang sudah
/// ada. Dipakai untuk kategori Pendapatan/Beban yang belum tercakup tanpa
/// perlu update aplikasi tiap kali ada akun baru.
class CustomLineItem {
  final String id;
  final String label;
  final double value;
  final String keterangan;

  const CustomLineItem({
    required this.id,
    required this.label,
    this.value = 0,
    this.keterangan = '',
  });

  CustomLineItem copyWith({String? label, double? value, String? keterangan}) {
    return CustomLineItem(
      id: id,
      label: label ?? this.label,
      value: value ?? this.value,
      keterangan: keterangan ?? this.keterangan,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'value': value,
        'keterangan': keterangan,
      };

  factory CustomLineItem.fromMap(Map<String, Object?> map) => CustomLineItem(
        id: map['id'] as String? ?? '',
        label: map['label'] as String? ?? '',
        value: (map['value'] as num?)?.toDouble() ?? 0,
        keterangan: map['keterangan'] as String? ?? '',
      );
}

List<CustomLineItem> _decodeCustomItems(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json) as List;
    return decoded
        .map((e) => CustomLineItem.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
  } catch (_) {
    return const [];
  }
}

String _encodeCustomItems(List<CustomLineItem> items) =>
    jsonEncode(items.map((e) => e.toMap()).toList());

/// Merepresentasikan satu periode pembukuan.
///
/// Semua nominal disimpan sebagai [double] dalam satuan Rupiah.
class Period {
  final int? id;
  final PeriodType periodType;
  final int? month; // 1-12, hanya diisi jika periodType == calendar
  final int? year; // hanya diisi jika periodType == calendar
  final DateTime startDate;
  final DateTime endDate;
  final String? customLabel; // opsional, hanya dipakai untuk periodType == custom

  // --- Pendapatan (hasil olah upload Excel, per kategori) ---
  final double penjualanCash;
  final double penjualanQrisMandiri;
  final double penjualanEdcOnUs;
  final double penjualanEdcOffUs;
  final double penjualanGofood;
  final double penjualanGrabfood;
  final double penjualanQrisEsb;
  final double penjualanOther;
  final double pendapatanBunga;
  // Service Charge yang terkumpul dari customer periode ini -- SUDAH
  // termasuk di dalam penjualanCash/QRIS/EDC/dst di atas (SC dipungut
  // bersamaan dengan pembayaran lewat channel apapun), field ini HANYA
  // dipakai untuk mengeluarkannya kembali sebagai basis Alokasi Laba (lihat
  // getter omsetBersihExclSC) -- karena SC adalah hak karyawan (kewajiban
  // 20.3 Utang Service Charge Karyawan), bukan omset milik usaha. Jangan
  // dikurangkan dari totalPenjualan, karena totalPenjualan (termasuk SC)
  // tetap jadi basis pajak PBJT/PPh Final yang benar (DPP restoran memang
  // mengikutkan SC).
  final double scTerkumpul;

  // --- Pembelian ---
  final double saldoAwal;
  final double totalPembelianBahanBaku; // hasil olah upload Excel
  final double persediaanAkhir;

  // --- Beban operasional ---
  final double bebanGajiKaryawan;
  final double bebanListrikBulanan;
  final double bebanListrikDuaMingguan;
  final double bebanIpl;
  final double bebanSuppliesCleaning;
  final double bebanMdrQris;
  final double bebanMdrEdc;
  final double bebanMdrEsb;
  final double bebanMdrGofood;
  final double bebanMdrGrabfood;
  final double bebanMarketing;
  final double bebanAdmTransfer;
  final double bebanKartuDebit;
  final double bebanAdminRekening;
  final double bebanPajakRekening;
  final double bebanLainLain;
  final double bebanBiayaAkomodasi;
  final double bebanBiayaServiceKaryawan;
  final double bebanPenyusutanBar;
  final double bebanPenyusutanKitchen;
  final double bebanPenyusutanFurnitureArea;
  final double bebanPenyusutanOffice;
  final double bebanWasteBahanBaku; // diisi manual, atau lewat sinkronisasi dari tab Stock

  // --- Akun tambahan (dinamis, ditambah manual lewat tombol "+ Tambah Akun") ---
  final List<CustomLineItem> customIncomeItems;
  final List<CustomLineItem> customExpenseItems;

  // --- Neraca (Laporan Posisi Keuangan): saldo akhir tiap akun per periode
  // ini -- lihat lib/models/posisi_keuangan.dart untuk cara akun-akun ini
  // dirakit jadi Assets = Liabilities + Equity. ---
  final List<CustomLineItem> kasBankItems; // Kas, Bank Mandiri, dst -- saldo akhir periode
  final double piutangUsaha; // Accounts Receivable, saldo akhir
  final double bebanDibayarDimuka; // Prepaid Expense, saldo akhir
  final List<CustomLineItem> customCurrentAssetItems; // akun aset lancar tambahan
  final double hutangUsaha; // Accounts Payable / hutang supplier, saldo akhir
  final double hutangGajiKaryawan; // Accrued Salary Payable, saldo akhir
  final double hutangPb1; // PB1 Payable, saldo akhir
  final double hutangPph21; // PPh 21 Payable, saldo akhir
  final double hutangPph23; // PPh 23 Payable, saldo akhir
  final double hutangPajakBadan; // Corporate Income Tax Payable, saldo akhir
  final double hutangServiceCharge; // Service Charge Payable, saldo akhir
  final double hutangLainLain; // Other Payable, saldo akhir
  final double pendapatanDiterimaDimuka; // Unearned Revenue (DP customer), saldo akhir
  final double pinjaman; // Loan Payable, saldo akhir
  final List<CustomLineItem> customLiabilityItems; // akun hutang tambahan

  // --- Tax Control: PBJT/PB1 (default 10% dari Total Penjualan) & PPh Final
  // UMKM (default 0.5% dari Total Penjualan) -- Tax Payable dihitung otomatis
  // (lihat getter di bawah), field ini hanya menyimpan bagian yang manual:
  // berapa yang sudah dibayar & berapa yang sudah disisihkan (Tax Fund).
  // Jatuh tempo dihitung otomatis dari endDate (lihat getter), tidak
  // disimpan manual.
  final double pbjtTaxPaid;
  final double pbjtTaxFund;
  final double pphFinalTaxPaid;
  final double pphFinalTaxFund;

  // Modal & Prive: nilai yang ditambahkan/dikurangi PADA PERIODE INI saja
  // (bukan saldo akhir kumulatif) -- akumulasinya dihitung lintas periode di
  // buildPosisiKeuangan.
  final double modalDisetorPeriodeIni;
  final double privePeriodeIni;

  const Period({
    this.id,
    required this.periodType,
    this.month,
    this.year,
    required this.startDate,
    required this.endDate,
    this.customLabel,
    this.penjualanCash = 0,
    this.penjualanQrisMandiri = 0,
    this.penjualanEdcOnUs = 0,
    this.penjualanEdcOffUs = 0,
    this.penjualanGofood = 0,
    this.penjualanGrabfood = 0,
    this.penjualanQrisEsb = 0,
    this.penjualanOther = 0,
    this.pendapatanBunga = 0,
    this.scTerkumpul = 0,
    this.saldoAwal = 0,
    this.totalPembelianBahanBaku = 0,
    this.persediaanAkhir = 0,
    this.bebanGajiKaryawan = 0,
    this.bebanListrikBulanan = 0,
    this.bebanListrikDuaMingguan = 0,
    this.bebanIpl = 0,
    this.bebanSuppliesCleaning = 0,
    this.bebanMdrQris = 0,
    this.bebanMdrEdc = 0,
    this.bebanMdrEsb = 0,
    this.bebanMdrGofood = 0,
    this.bebanMdrGrabfood = 0,
    this.bebanMarketing = 0,
    this.bebanAdmTransfer = 0,
    this.bebanKartuDebit = 0,
    this.bebanAdminRekening = 0,
    this.bebanPajakRekening = 0,
    this.bebanLainLain = 0,
    this.bebanBiayaAkomodasi = 0,
    this.bebanBiayaServiceKaryawan = 0,
    this.bebanPenyusutanBar = 0,
    this.bebanPenyusutanKitchen = 0,
    this.bebanPenyusutanFurnitureArea = 0,
    this.bebanPenyusutanOffice = 0,
    this.bebanWasteBahanBaku = 0,
    this.customIncomeItems = const [],
    this.customExpenseItems = const [],
    this.kasBankItems = const [],
    this.piutangUsaha = 0,
    this.bebanDibayarDimuka = 0,
    this.customCurrentAssetItems = const [],
    this.hutangUsaha = 0,
    this.hutangGajiKaryawan = 0,
    this.hutangPb1 = 0,
    this.hutangPph21 = 0,
    this.hutangPph23 = 0,
    this.hutangPajakBadan = 0,
    this.hutangServiceCharge = 0,
    this.hutangLainLain = 0,
    this.pendapatanDiterimaDimuka = 0,
    this.pinjaman = 0,
    this.customLiabilityItems = const [],
    this.pbjtTaxPaid = 0,
    this.pbjtTaxFund = 0,
    this.pphFinalTaxPaid = 0,
    this.pphFinalTaxFund = 0,
    this.modalDisetorPeriodeIni = 0,
    this.privePeriodeIni = 0,
  });

  /// Buat periode baru berbasis bulan kalender penuh (tgl 1 s/d akhir bulan).
  factory Period.calendarMonth({int? id, required int month, required int year}) {
    return Period(
      id: id,
      periodType: PeriodType.calendar,
      month: month,
      year: year,
      startDate: DateTime(year, month, 1),
      endDate: DateTime(year, month + 1, 0),
    );
  }

  /// Buat periode baru berbasis rentang tanggal bebas, mis. siklus tagihan
  /// 26 Juni - 25 Juli.
  factory Period.customRange({
    int? id,
    required DateTime startDate,
    required DateTime endDate,
    String? customLabel,
  }) {
    return Period(
      id: id,
      periodType: PeriodType.custom,
      startDate: startDate,
      endDate: endDate,
      customLabel: customLabel,
    );
  }

  static const monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String get label {
    if (periodType == PeriodType.calendar && month != null && year != null) {
      return '${monthNames[month! - 1]} $year';
    }
    if (customLabel != null && customLabel!.trim().isNotEmpty) {
      return customLabel!.trim();
    }
    return _rangeLabel;
  }

  String get _rangeLabel {
    final sameYear = startDate.year == endDate.year;
    final startFmt =
        DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy', 'id_ID').format(startDate);
    final endFmt = DateFormat('d MMM yyyy', 'id_ID').format(endDate);
    return '$startFmt - $endFmt';
  }

  // --- Kalkulasi turunan ---

  double get totalPenjualan =>
      penjualanCash +
      penjualanQrisMandiri +
      penjualanEdcOnUs +
      penjualanEdcOffUs +
      penjualanGofood +
      penjualanGrabfood +
      penjualanQrisEsb +
      penjualanOther +
      pendapatanBunga +
      customIncomeItems.fold(0.0, (a, i) => a + i.value);

  /// Omset bersih dipakai KHUSUS sebagai basis Alokasi Laba (Reserve/
  /// Maintenance/R&D) -- mengeluarkan SC karena SC adalah hak karyawan
  /// (kewajiban 20.3), bukan omset usaha. JANGAN dipakai untuk basis pajak
  /// PBJT/PPh Final -- keduanya tetap pakai [totalPenjualan] (termasuk SC).
  double get omsetBersihExclSC => totalPenjualan - scTerkumpul;

  /// Total beban Listrik (gabungan 3 field input: bulanan, per 2 minggu, IPL)
  /// -- ditampilkan sebagai satu baris "Listrik" di laporan/export.
  double get bebanListrikTotal => bebanListrikBulanan + bebanListrikDuaMingguan + bebanIpl;

  /// HPP = Saldo Awal + Total Pembelian Bahan Baku - Persediaan Akhir
  double get hpp => saldoAwal + totalPembelianBahanBaku - persediaanAkhir;

  double get totalBeban =>
      bebanGajiKaryawan +
      bebanListrikTotal +
      bebanSuppliesCleaning +
      bebanMdrQris +
      bebanMdrEdc +
      bebanMdrEsb +
      bebanMdrGofood +
      bebanMdrGrabfood +
      bebanMarketing +
      bebanAdmTransfer +
      bebanKartuDebit +
      bebanAdminRekening +
      bebanPajakRekening +
      bebanLainLain +
      bebanBiayaAkomodasi +
      bebanBiayaServiceKaryawan +
      bebanPenyusutanBar +
      bebanPenyusutanKitchen +
      bebanPenyusutanFurnitureArea +
      bebanPenyusutanOffice +
      bebanWasteBahanBaku +
      customExpenseItems.fold(0.0, (a, i) => a + i.value);

  /// Laba kotor = Penjualan - Pembelian (HPP)
  double get labaKotor => totalPenjualan - hpp;

  /// Laba bersih = Laba kotor - Beban operasional
  double get labaBersih => labaKotor - totalBeban;

  double _pctOfPenjualan(double value) =>
      totalPenjualan == 0 ? 0 : (value / totalPenjualan) * 100;

  /// Total seluruh akun Kas & Bank pada akhir periode ini.
  double get totalKasBank => kasBankItems.fold(0.0, (a, i) => a + i.value);

  /// Total Hutang Pajak (PB1 + PPh 21 + PPh 23 + Pajak Badan) akhir periode.
  double get totalHutangPajak => hutangPb1 + hutangPph21 + hutangPph23 + hutangPajakBadan;

  // --- Tax Control (lihat catatan field di atas) ---
  // Tax Base kedua pajak ini sama: Total Penjualan periode ini.
  double pbjtTaxPayable(double ratePersen) => totalPenjualan * ratePersen / 100;
  double pphFinalTaxPayable(double ratePersen) => totalPenjualan * ratePersen / 100;

  /// Jatuh tempo PBJT/PB1: tanggal 10 bulan berikutnya setelah akhir periode.
  DateTime get pbjtDueDate => DateTime(endDate.year, endDate.month + 1, 10);

  /// Jatuh tempo PPh Final UMKM: tanggal 15 bulan berikutnya setelah akhir periode.
  DateTime get pphFinalDueDate => DateTime(endDate.year, endDate.month + 1, 15);

  double get grossProfitMargin => _pctOfPenjualan(labaKotor);
  double get netProfitMargin => _pctOfPenjualan(labaBersih);
  double get foodCostRatio => _pctOfPenjualan(hpp);
  double get operatingExpenseRatio => _pctOfPenjualan(totalBeban);
  double get laborCostRatio => _pctOfPenjualan(bebanGajiKaryawan);

  Period copyWith({
    int? id,
    PeriodType? periodType,
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    String? customLabel,
    double? penjualanCash,
    double? penjualanQrisMandiri,
    double? penjualanEdcOnUs,
    double? penjualanEdcOffUs,
    double? penjualanGofood,
    double? penjualanGrabfood,
    double? penjualanQrisEsb,
    double? penjualanOther,
    double? pendapatanBunga,
    double? saldoAwal,
    double? totalPembelianBahanBaku,
    double? persediaanAkhir,
    double? bebanGajiKaryawan,
    double? bebanListrikBulanan,
    double? bebanListrikDuaMingguan,
    double? bebanIpl,
    double? bebanSuppliesCleaning,
    double? bebanMdrQris,
    double? bebanMdrEdc,
    double? bebanMdrEsb,
    double? bebanMdrGofood,
    double? bebanMdrGrabfood,
    double? bebanMarketing,
    double? bebanAdmTransfer,
    double? bebanKartuDebit,
    double? bebanAdminRekening,
    double? bebanPajakRekening,
    double? bebanLainLain,
    double? bebanBiayaAkomodasi,
    double? bebanBiayaServiceKaryawan,
    double? bebanPenyusutanBar,
    double? bebanPenyusutanKitchen,
    double? bebanPenyusutanFurnitureArea,
    double? bebanPenyusutanOffice,
    double? bebanWasteBahanBaku,
    List<CustomLineItem>? customIncomeItems,
    List<CustomLineItem>? customExpenseItems,
    List<CustomLineItem>? kasBankItems,
    double? piutangUsaha,
    double? bebanDibayarDimuka,
    List<CustomLineItem>? customCurrentAssetItems,
    double? hutangUsaha,
    double? hutangGajiKaryawan,
    double? hutangPb1,
    double? hutangPph21,
    double? hutangPph23,
    double? hutangPajakBadan,
    double? hutangServiceCharge,
    double? hutangLainLain,
    double? pendapatanDiterimaDimuka,
    double? pinjaman,
    List<CustomLineItem>? customLiabilityItems,
    double? pbjtTaxPaid,
    double? pbjtTaxFund,
    double? pphFinalTaxPaid,
    double? pphFinalTaxFund,
    double? modalDisetorPeriodeIni,
    double? privePeriodeIni,
    double? scTerkumpul,
  }) {
    return Period(
      id: id ?? this.id,
      periodType: periodType ?? this.periodType,
      month: month ?? this.month,
      year: year ?? this.year,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customLabel: customLabel ?? this.customLabel,
      penjualanCash: penjualanCash ?? this.penjualanCash,
      penjualanQrisMandiri: penjualanQrisMandiri ?? this.penjualanQrisMandiri,
      penjualanEdcOnUs: penjualanEdcOnUs ?? this.penjualanEdcOnUs,
      penjualanEdcOffUs: penjualanEdcOffUs ?? this.penjualanEdcOffUs,
      penjualanGofood: penjualanGofood ?? this.penjualanGofood,
      penjualanGrabfood: penjualanGrabfood ?? this.penjualanGrabfood,
      penjualanQrisEsb: penjualanQrisEsb ?? this.penjualanQrisEsb,
      penjualanOther: penjualanOther ?? this.penjualanOther,
      pendapatanBunga: pendapatanBunga ?? this.pendapatanBunga,
      saldoAwal: saldoAwal ?? this.saldoAwal,
      totalPembelianBahanBaku: totalPembelianBahanBaku ?? this.totalPembelianBahanBaku,
      persediaanAkhir: persediaanAkhir ?? this.persediaanAkhir,
      bebanGajiKaryawan: bebanGajiKaryawan ?? this.bebanGajiKaryawan,
      bebanListrikBulanan: bebanListrikBulanan ?? this.bebanListrikBulanan,
      bebanListrikDuaMingguan: bebanListrikDuaMingguan ?? this.bebanListrikDuaMingguan,
      bebanIpl: bebanIpl ?? this.bebanIpl,
      bebanSuppliesCleaning: bebanSuppliesCleaning ?? this.bebanSuppliesCleaning,
      bebanMdrQris: bebanMdrQris ?? this.bebanMdrQris,
      bebanMdrEdc: bebanMdrEdc ?? this.bebanMdrEdc,
      bebanMdrEsb: bebanMdrEsb ?? this.bebanMdrEsb,
      bebanMdrGofood: bebanMdrGofood ?? this.bebanMdrGofood,
      bebanMdrGrabfood: bebanMdrGrabfood ?? this.bebanMdrGrabfood,
      bebanMarketing: bebanMarketing ?? this.bebanMarketing,
      bebanAdmTransfer: bebanAdmTransfer ?? this.bebanAdmTransfer,
      bebanKartuDebit: bebanKartuDebit ?? this.bebanKartuDebit,
      bebanAdminRekening: bebanAdminRekening ?? this.bebanAdminRekening,
      bebanPajakRekening: bebanPajakRekening ?? this.bebanPajakRekening,
      bebanLainLain: bebanLainLain ?? this.bebanLainLain,
      bebanBiayaAkomodasi: bebanBiayaAkomodasi ?? this.bebanBiayaAkomodasi,
      bebanBiayaServiceKaryawan: bebanBiayaServiceKaryawan ?? this.bebanBiayaServiceKaryawan,
      bebanPenyusutanBar: bebanPenyusutanBar ?? this.bebanPenyusutanBar,
      bebanPenyusutanKitchen: bebanPenyusutanKitchen ?? this.bebanPenyusutanKitchen,
      bebanPenyusutanFurnitureArea:
          bebanPenyusutanFurnitureArea ?? this.bebanPenyusutanFurnitureArea,
      bebanPenyusutanOffice: bebanPenyusutanOffice ?? this.bebanPenyusutanOffice,
      bebanWasteBahanBaku: bebanWasteBahanBaku ?? this.bebanWasteBahanBaku,
      customIncomeItems: customIncomeItems ?? this.customIncomeItems,
      customExpenseItems: customExpenseItems ?? this.customExpenseItems,
      kasBankItems: kasBankItems ?? this.kasBankItems,
      piutangUsaha: piutangUsaha ?? this.piutangUsaha,
      bebanDibayarDimuka: bebanDibayarDimuka ?? this.bebanDibayarDimuka,
      customCurrentAssetItems: customCurrentAssetItems ?? this.customCurrentAssetItems,
      hutangUsaha: hutangUsaha ?? this.hutangUsaha,
      hutangGajiKaryawan: hutangGajiKaryawan ?? this.hutangGajiKaryawan,
      hutangPb1: hutangPb1 ?? this.hutangPb1,
      hutangPph21: hutangPph21 ?? this.hutangPph21,
      hutangPph23: hutangPph23 ?? this.hutangPph23,
      hutangPajakBadan: hutangPajakBadan ?? this.hutangPajakBadan,
      hutangServiceCharge: hutangServiceCharge ?? this.hutangServiceCharge,
      hutangLainLain: hutangLainLain ?? this.hutangLainLain,
      pendapatanDiterimaDimuka: pendapatanDiterimaDimuka ?? this.pendapatanDiterimaDimuka,
      pinjaman: pinjaman ?? this.pinjaman,
      customLiabilityItems: customLiabilityItems ?? this.customLiabilityItems,
      pbjtTaxPaid: pbjtTaxPaid ?? this.pbjtTaxPaid,
      pbjtTaxFund: pbjtTaxFund ?? this.pbjtTaxFund,
      pphFinalTaxPaid: pphFinalTaxPaid ?? this.pphFinalTaxPaid,
      pphFinalTaxFund: pphFinalTaxFund ?? this.pphFinalTaxFund,
      modalDisetorPeriodeIni: modalDisetorPeriodeIni ?? this.modalDisetorPeriodeIni,
      privePeriodeIni: privePeriodeIni ?? this.privePeriodeIni,
      scTerkumpul: scTerkumpul ?? this.scTerkumpul,
    );
  }

  static String _dateToIso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static DateTime _dateFromIso(String s) => DateFormat('yyyy-MM-dd').parse(s);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'period_type': periodType.name,
      'month': month,
      'year': year,
      'start_date': _dateToIso(startDate),
      'end_date': _dateToIso(endDate),
      'custom_label': customLabel,
      'penjualan_cash': penjualanCash,
      'penjualan_qris_mandiri': penjualanQrisMandiri,
      'penjualan_edc_on_us': penjualanEdcOnUs,
      'penjualan_edc_off_us': penjualanEdcOffUs,
      'penjualan_gofood': penjualanGofood,
      'penjualan_grabfood': penjualanGrabfood,
      'penjualan_qris_esb': penjualanQrisEsb,
      'penjualan_other': penjualanOther,
      'pendapatan_bunga': pendapatanBunga,
      'saldo_awal': saldoAwal,
      'total_pembelian_bahan_baku': totalPembelianBahanBaku,
      'persediaan_akhir': persediaanAkhir,
      'beban_gaji_karyawan': bebanGajiKaryawan,
      'beban_listrik_bulanan': bebanListrikBulanan,
      'beban_listrik_dua_mingguan': bebanListrikDuaMingguan,
      'beban_ipl': bebanIpl,
      'beban_supplies_cleaning': bebanSuppliesCleaning,
      'beban_mdr_qris': bebanMdrQris,
      'beban_mdr_edc': bebanMdrEdc,
      'beban_mdr_esb': bebanMdrEsb,
      'beban_mdr_gofood': bebanMdrGofood,
      'beban_mdr_grabfood': bebanMdrGrabfood,
      'beban_marketing': bebanMarketing,
      'beban_adm_transfer': bebanAdmTransfer,
      'beban_kartu_debit': bebanKartuDebit,
      'beban_admin_rekening': bebanAdminRekening,
      'beban_pajak_rekening': bebanPajakRekening,
      'beban_lain_lain': bebanLainLain,
      'beban_biaya_akomodasi': bebanBiayaAkomodasi,
      'beban_biaya_service_karyawan': bebanBiayaServiceKaryawan,
      'beban_penyusutan_bar': bebanPenyusutanBar,
      'beban_penyusutan_kitchen': bebanPenyusutanKitchen,
      'beban_penyusutan_furniture_area': bebanPenyusutanFurnitureArea,
      'beban_penyusutan_office': bebanPenyusutanOffice,
      'beban_waste_bahan_baku': bebanWasteBahanBaku,
      'custom_income_items': _encodeCustomItems(customIncomeItems),
      'custom_expense_items': _encodeCustomItems(customExpenseItems),
      'kas_bank_items': _encodeCustomItems(kasBankItems),
      'piutang_usaha': piutangUsaha,
      'beban_dibayar_dimuka': bebanDibayarDimuka,
      'custom_current_asset_items': _encodeCustomItems(customCurrentAssetItems),
      'hutang_usaha': hutangUsaha,
      'hutang_gaji_karyawan': hutangGajiKaryawan,
      'hutang_pb1': hutangPb1,
      'hutang_pph21': hutangPph21,
      'hutang_pph23': hutangPph23,
      'hutang_pajak_badan': hutangPajakBadan,
      'hutang_service_charge': hutangServiceCharge,
      'hutang_lain_lain': hutangLainLain,
      'pendapatan_diterima_dimuka': pendapatanDiterimaDimuka,
      'pinjaman': pinjaman,
      'custom_liability_items': _encodeCustomItems(customLiabilityItems),
      'pbjt_tax_paid': pbjtTaxPaid,
      'pbjt_tax_fund': pbjtTaxFund,
      'pph_final_tax_paid': pphFinalTaxPaid,
      'pph_final_tax_fund': pphFinalTaxFund,
      'modal_disetor_periode_ini': modalDisetorPeriodeIni,
      'prive_periode_ini': privePeriodeIni,
      'sc_terkumpul': scTerkumpul,
    };
  }

  factory Period.fromMap(Map<String, Object?> map) {
    double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return Period(
      id: map['id'] as int?,
      periodType: (map['period_type'] as String?) == 'custom'
          ? PeriodType.custom
          : PeriodType.calendar,
      month: map['month'] as int?,
      year: map['year'] as int?,
      startDate: _dateFromIso(map['start_date'] as String),
      endDate: _dateFromIso(map['end_date'] as String),
      customLabel: map['custom_label'] as String?,
      penjualanCash: d('penjualan_cash'),
      penjualanQrisMandiri: d('penjualan_qris_mandiri'),
      penjualanEdcOnUs: d('penjualan_edc_on_us'),
      penjualanEdcOffUs: d('penjualan_edc_off_us'),
      penjualanGofood: d('penjualan_gofood'),
      penjualanGrabfood: d('penjualan_grabfood'),
      penjualanQrisEsb: d('penjualan_qris_esb'),
      penjualanOther: d('penjualan_other'),
      pendapatanBunga: d('pendapatan_bunga'),
      scTerkumpul: d('sc_terkumpul'),
      saldoAwal: d('saldo_awal'),
      totalPembelianBahanBaku: d('total_pembelian_bahan_baku'),
      persediaanAkhir: d('persediaan_akhir'),
      bebanGajiKaryawan: d('beban_gaji_karyawan'),
      bebanListrikBulanan: d('beban_listrik_bulanan'),
      bebanListrikDuaMingguan: d('beban_listrik_dua_mingguan'),
      bebanIpl: d('beban_ipl'),
      bebanSuppliesCleaning: d('beban_supplies_cleaning'),
      bebanMdrQris: d('beban_mdr_qris'),
      bebanMdrEdc: d('beban_mdr_edc'),
      bebanMdrEsb: d('beban_mdr_esb'),
      bebanMdrGofood: d('beban_mdr_gofood'),
      bebanMdrGrabfood: d('beban_mdr_grabfood'),
      bebanMarketing: d('beban_marketing'),
      bebanAdmTransfer: d('beban_adm_transfer'),
      bebanKartuDebit: d('beban_kartu_debit'),
      bebanAdminRekening: d('beban_admin_rekening'),
      bebanPajakRekening: d('beban_pajak_rekening'),
      bebanLainLain: d('beban_lain_lain'),
      bebanBiayaAkomodasi: d('beban_biaya_akomodasi'),
      bebanBiayaServiceKaryawan: d('beban_biaya_service_karyawan'),
      bebanPenyusutanBar: d('beban_penyusutan_bar'),
      bebanPenyusutanKitchen: d('beban_penyusutan_kitchen'),
      bebanPenyusutanFurnitureArea: d('beban_penyusutan_furniture_area'),
      bebanPenyusutanOffice: d('beban_penyusutan_office'),
      bebanWasteBahanBaku: d('beban_waste_bahan_baku'),
      customIncomeItems: _decodeCustomItems(map['custom_income_items'] as String?),
      customExpenseItems: _decodeCustomItems(map['custom_expense_items'] as String?),
      kasBankItems: _decodeCustomItems(map['kas_bank_items'] as String?),
      piutangUsaha: d('piutang_usaha'),
      bebanDibayarDimuka: d('beban_dibayar_dimuka'),
      customCurrentAssetItems:
          _decodeCustomItems(map['custom_current_asset_items'] as String?),
      hutangUsaha: d('hutang_usaha'),
      hutangGajiKaryawan: d('hutang_gaji_karyawan'),
      hutangPb1: d('hutang_pb1'),
      hutangPph21: d('hutang_pph21'),
      hutangPph23: d('hutang_pph23'),
      hutangPajakBadan: d('hutang_pajak_badan'),
      hutangServiceCharge: d('hutang_service_charge'),
      hutangLainLain: d('hutang_lain_lain'),
      pendapatanDiterimaDimuka: d('pendapatan_diterima_dimuka'),
      pinjaman: d('pinjaman'),
      customLiabilityItems: _decodeCustomItems(map['custom_liability_items'] as String?),
      pbjtTaxPaid: d('pbjt_tax_paid'),
      pbjtTaxFund: d('pbjt_tax_fund'),
      pphFinalTaxPaid: d('pph_final_tax_paid'),
      pphFinalTaxFund: d('pph_final_tax_fund'),
      modalDisetorPeriodeIni: d('modal_disetor_periode_ini'),
      privePeriodeIni: d('prive_periode_ini'),
    );
  }
}

/// Jumlahkan semua periode dalam satu tahun (ditentukan dari `startDate.year`
/// tiap periode, berlaku untuk periode kalender maupun rentang custom) jadi
/// satu [Period] sintetis untuk laporan Ringkasan Tahunan. Karena hasilnya
/// tetap objek [Period] biasa, semua getter turunan (totalPenjualan, hpp,
/// totalBeban, labaBersih, rasio-rasio) dan fungsi build*List/export yang
/// sudah ada otomatis bisa dipakai tanpa perubahan apapun.
Period aggregateYear(int year, List<Period> periodsInYear) {
  double sum(double Function(Period) f) => periodsInYear.fold(0.0, (a, p) => a + f(p));

  // Gabungkan akun tambahan dari semua periode di tahun ini: akun dengan
  // nama yang sama (case-insensitive) dijumlahkan jadi satu baris, supaya
  // laporan tahunan tidak menampilkan baris berulang per bulan.
  List<CustomLineItem> mergeCustom(List<CustomLineItem> Function(Period) select) {
    final merged = <String, CustomLineItem>{};
    for (final p in periodsInYear) {
      for (final item in select(p)) {
        final key = item.label.trim().toLowerCase();
        if (key.isEmpty) continue;
        final existing = merged[key];
        merged[key] = existing == null
            ? item
            : existing.copyWith(
                value: existing.value + item.value,
                keterangan: existing.keterangan.isEmpty ? item.keterangan : existing.keterangan,
              );
      }
    }
    return merged.values.toList();
  }

  return Period(
    periodType: PeriodType.custom,
    startDate: DateTime(year, 1, 1),
    endDate: DateTime(year, 12, 31),
    customLabel: 'Tahun $year',
    penjualanCash: sum((p) => p.penjualanCash),
    penjualanQrisMandiri: sum((p) => p.penjualanQrisMandiri),
    penjualanEdcOnUs: sum((p) => p.penjualanEdcOnUs),
    penjualanEdcOffUs: sum((p) => p.penjualanEdcOffUs),
    penjualanGofood: sum((p) => p.penjualanGofood),
    penjualanGrabfood: sum((p) => p.penjualanGrabfood),
    penjualanQrisEsb: sum((p) => p.penjualanQrisEsb),
    penjualanOther: sum((p) => p.penjualanOther),
    pendapatanBunga: sum((p) => p.pendapatanBunga),
    scTerkumpul: sum((p) => p.scTerkumpul),
    saldoAwal: sum((p) => p.saldoAwal),
    totalPembelianBahanBaku: sum((p) => p.totalPembelianBahanBaku),
    persediaanAkhir: sum((p) => p.persediaanAkhir),
    bebanGajiKaryawan: sum((p) => p.bebanGajiKaryawan),
    bebanListrikBulanan: sum((p) => p.bebanListrikBulanan),
    bebanListrikDuaMingguan: sum((p) => p.bebanListrikDuaMingguan),
    bebanIpl: sum((p) => p.bebanIpl),
    bebanSuppliesCleaning: sum((p) => p.bebanSuppliesCleaning),
    bebanMdrQris: sum((p) => p.bebanMdrQris),
    bebanMdrEdc: sum((p) => p.bebanMdrEdc),
    bebanMdrEsb: sum((p) => p.bebanMdrEsb),
    bebanMdrGofood: sum((p) => p.bebanMdrGofood),
    bebanMdrGrabfood: sum((p) => p.bebanMdrGrabfood),
    bebanMarketing: sum((p) => p.bebanMarketing),
    bebanAdmTransfer: sum((p) => p.bebanAdmTransfer),
    bebanKartuDebit: sum((p) => p.bebanKartuDebit),
    bebanAdminRekening: sum((p) => p.bebanAdminRekening),
    bebanPajakRekening: sum((p) => p.bebanPajakRekening),
    bebanLainLain: sum((p) => p.bebanLainLain),
    bebanBiayaAkomodasi: sum((p) => p.bebanBiayaAkomodasi),
    bebanBiayaServiceKaryawan: sum((p) => p.bebanBiayaServiceKaryawan),
    bebanPenyusutanBar: sum((p) => p.bebanPenyusutanBar),
    bebanPenyusutanKitchen: sum((p) => p.bebanPenyusutanKitchen),
    bebanPenyusutanFurnitureArea: sum((p) => p.bebanPenyusutanFurnitureArea),
    bebanPenyusutanOffice: sum((p) => p.bebanPenyusutanOffice),
    bebanWasteBahanBaku: sum((p) => p.bebanWasteBahanBaku),
    customIncomeItems: mergeCustom((p) => p.customIncomeItems),
    customExpenseItems: mergeCustom((p) => p.customExpenseItems),
  );
}

/// Satu baris pada tabel ringkasan rasio keuangan.
class RasioInfo {
  final String nama;
  final double hasil;
  final String standarIdeal;
  final bool Function(double hasil) isIdeal;

  const RasioInfo({
    required this.nama,
    required this.hasil,
    required this.standarIdeal,
    required this.isIdeal,
  });
}

List<RasioInfo> buildRasioList(Period p) {
  return [
    RasioInfo(
      nama: 'Gross Profit Margin',
      hasil: p.grossProfitMargin,
      standarIdeal: '> 60% (Baik)',
      isIdeal: (h) => h > 60,
    ),
    RasioInfo(
      nama: 'Net Profit Margin',
      hasil: p.netProfitMargin,
      standarIdeal: '15% - 25% (Sehat)',
      isIdeal: (h) => h >= 15 && h <= 25,
    ),
    RasioInfo(
      nama: 'Food Cost Ratio',
      hasil: p.foodCostRatio,
      standarIdeal: '30% - 35% (Baik)',
      isIdeal: (h) => h >= 30 && h <= 35,
    ),
    RasioInfo(
      nama: 'Operating Expense Ratio',
      hasil: p.operatingExpenseRatio,
      standarIdeal: '20% - 30% (Sehat)',
      isIdeal: (h) => h >= 20 && h <= 30,
    ),
    RasioInfo(
      nama: 'Labor Cost Ratio',
      hasil: p.laborCostRatio,
      standarIdeal: '15% - 25% (Sehat)',
      isIdeal: (h) => h >= 15 && h <= 25,
    ),
  ];
}

/// Satu baris kategori Pendapatan, dipakai di tab Ringkasan & export.
class PendapatanRow {
  final String label;
  final double value;

  const PendapatanRow({required this.label, required this.value});
}

/// Gabungkan nama akun dengan keterangan-nya jadi satu label tampilan, mis.
/// "Sewa Alat (sewa proyektor acara kantor)" -- supaya keterangan yang
/// diisi user ikut terlihat di kartu Ringkasan maupun export Excel/PDF tanpa
/// perlu menambah kolom baru di semua tempat yang sudah ada.
String _withKeterangan(String label, String keterangan) {
  final k = keterangan.trim();
  return k.isEmpty ? label : '$label ($k)';
}

List<PendapatanRow> buildPendapatanList(Period p) => [
      PendapatanRow(label: 'Income Cash', value: p.penjualanCash),
      PendapatanRow(label: 'Income Qris Mandiri', value: p.penjualanQrisMandiri),
      PendapatanRow(label: 'Income EDC On Us', value: p.penjualanEdcOnUs),
      PendapatanRow(label: 'Income EDC Off Us', value: p.penjualanEdcOffUs),
      PendapatanRow(label: 'Income Gofood', value: p.penjualanGofood),
      PendapatanRow(label: 'Income Grabfood', value: p.penjualanGrabfood),
      PendapatanRow(label: 'Income Qris ESB', value: p.penjualanQrisEsb),
      PendapatanRow(label: 'Income Other', value: p.penjualanOther),
      PendapatanRow(label: 'Pendapatan Bunga', value: p.pendapatanBunga),
      for (final item in p.customIncomeItems)
        PendapatanRow(
          label: _withKeterangan(item.label.isEmpty ? 'Akun Tambahan' : item.label, item.keterangan),
          value: item.value,
        ),
    ];

/// Satu baris kategori Beban Operasional, dipakai di tab Ringkasan & export.
/// Listrik ditampilkan sebagai satu baris gabungan dari 3 field input.
class BebanRow {
  final String label;
  final double value;

  const BebanRow({required this.label, required this.value});
}

List<BebanRow> buildBebanList(Period p) => [
      BebanRow(label: 'Gaji Karyawan', value: p.bebanGajiKaryawan),
      BebanRow(label: 'Listrik', value: p.bebanListrikTotal),
      BebanRow(label: 'Supplies & Cleaning', value: p.bebanSuppliesCleaning),
      BebanRow(label: 'MDR QRIS', value: p.bebanMdrQris),
      BebanRow(label: 'MDR EDC', value: p.bebanMdrEdc),
      BebanRow(label: 'MDR ESB', value: p.bebanMdrEsb),
      BebanRow(label: 'MDR Go-Food', value: p.bebanMdrGofood),
      BebanRow(label: 'MDR Grab-Food', value: p.bebanMdrGrabfood),
      BebanRow(label: 'Marketing', value: p.bebanMarketing),
      BebanRow(label: 'Biaya Adm Transfer', value: p.bebanAdmTransfer),
      BebanRow(label: 'Biaya Kartu Debit', value: p.bebanKartuDebit),
      BebanRow(label: 'Biaya Admin Rekening', value: p.bebanAdminRekening),
      BebanRow(label: 'Pajak Rekening', value: p.bebanPajakRekening),
      BebanRow(label: 'Lain-Lain', value: p.bebanLainLain),
      BebanRow(label: 'Biaya Akomodasi', value: p.bebanBiayaAkomodasi),
      BebanRow(label: 'Biaya Service Karyawan', value: p.bebanBiayaServiceKaryawan),
      BebanRow(label: 'Penyusutan Bar', value: p.bebanPenyusutanBar),
      BebanRow(label: 'Penyusutan Kitchen', value: p.bebanPenyusutanKitchen),
      BebanRow(label: 'Penyusutan Furniture Area', value: p.bebanPenyusutanFurnitureArea),
      BebanRow(label: 'Penyusutan Office', value: p.bebanPenyusutanOffice),
      BebanRow(label: 'Waste/Susut Bahan Baku', value: p.bebanWasteBahanBaku),
      for (final item in p.customExpenseItems)
        BebanRow(
          label: _withKeterangan(item.label.isEmpty ? 'Akun Tambahan' : item.label, item.keterangan),
          value: item.value,
        ),
    ];

/// Satu baris pada tabel Neraca Saldo: satu akun dengan saldo di sisi
/// debit ATAU kredit (bukan dua-duanya).
class NeracaSaldoRow {
  final String akun;
  final double debit;
  final double kredit;

  const NeracaSaldoRow({required this.akun, this.debit = 0, this.kredit = 0});
}

/// Bangun daftar Neraca Saldo dari ringkasan periode.
///
/// Aplikasi ini tidak punya buku besar double-entry, jadi neraca saldo
/// disusun dengan pendekatan neraca lajur: Persediaan Akhir ditaruh di sisi
/// kredit (mengurangi HPP), dan Laba/Rugi Bersih periode berjalan dipakai
/// sebagai baris penyeimbang (laba -> debit, rugi -> kredit). Ini otomatis
/// membuat total debit == total kredit karena identitas:
/// totalPenjualan + persediaanAkhir = saldoAwal + totalPembelianBahanBaku
///                                     + totalBeban + labaBersih
/// (langsung diturunkan dari rumus [Period.labaBersih] di atas).
List<NeracaSaldoRow> buildNeracaSaldoList(Period p) {
  final rows = <NeracaSaldoRow>[];

  void debit(String akun, double value) {
    if (value == 0) return;
    rows.add(NeracaSaldoRow(akun: akun, debit: value));
  }

  void kredit(String akun, double value) {
    if (value == 0) return;
    rows.add(NeracaSaldoRow(akun: akun, kredit: value));
  }

  debit('Saldo Awal Persediaan', p.saldoAwal);
  debit('Pembelian Bahan Baku', p.totalPembelianBahanBaku);
  for (final b in buildBebanList(p)) {
    debit('Beban ${b.label}', b.value);
  }

  for (final r in buildPendapatanList(p)) {
    kredit(r.label, r.value);
  }
  kredit('Persediaan Akhir', p.persediaanAkhir);

  final laba = p.labaBersih;
  if (laba > 0) {
    debit('Laba Bersih Periode Berjalan', laba);
  } else if (laba < 0) {
    kredit('Rugi Bersih Periode Berjalan', -laba);
  }

  return rows;
}
