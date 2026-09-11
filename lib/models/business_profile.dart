/// Profil usaha & info pembayaran yang dipakai berulang di setiap invoice
/// yang di-generate (nama usaha, alamat, rekening bank, dan kontak person
/// yang dicantumkan di pojok kanan bawah invoice). Disimpan satu baris saja
/// di database (id selalu 1) supaya cukup diisi sekali lalu dipakai ulang.
class BusinessProfile {
  final String namaUsaha;
  final String alamatUsaha;
  final String metodePembayaran;
  final String namaBank;
  final String namaAkunBank;
  final String noRekening;
  final String kodeInvoice;
  final String namaKontak;
  final String noKontak;
  final int nextInvoiceSeq;

  /// Modal awal usaha (Paid-in Capital) sebelum periode-periode di aplikasi
  /// ini mulai dicatat -- nilai tetap, sekali diisi, dipakai sebagai basis
  /// Ekuitas di Laporan Posisi Keuangan (lihat lib/models/posisi_keuangan.dart).
  final double modalAwalUsaha;

  // --- Alokasi Laba (persentase, diisi sekali lalu dipakai berulang di
  // layar Ringkasan Tahunan > Alokasi Laba) -- basis: % dari Total Penjualan
  // (Omset) tahunan, bukan dari nominal Laba Bersih. Owner Distribution
  // adalah sisa (Laba Bersih - Reserve - Maintenance - Next Business Fund),
  // jadi tidak punya field persentase sendiri.
  final double pctReserve;
  final double pctMaintenance;
  final double pctNextBusinessFund;

  /// Target Cash Reserve = rata-rata Beban Operasional bulanan x jumlah
  /// bulan ini (lazimnya 3-6 bulan).
  final int cashReserveBulan;

  // --- Tax Control: tarif pajak, diisi sekali lalu dipakai untuk hitung
  // Tax Payable otomatis dari Total Penjualan tiap periode.
  final double pbjtTaxRatePersen; // PBJT/PB1, default 10%
  final double pphFinalTaxRatePersen; // PPh Final UMKM dari omset, default 0.5%

  const BusinessProfile({
    this.namaUsaha = '',
    this.alamatUsaha = '',
    this.metodePembayaran = 'Bank Transfer',
    this.namaBank = '',
    this.namaAkunBank = '',
    this.noRekening = '',
    this.kodeInvoice = '',
    this.namaKontak = '',
    this.noKontak = '',
    this.nextInvoiceSeq = 1,
    this.modalAwalUsaha = 0,
    this.pctReserve = 1,
    this.pctMaintenance = 1,
    this.pctNextBusinessFund = 1.5,
    this.cashReserveBulan = 4,
    this.pbjtTaxRatePersen = 10,
    this.pphFinalTaxRatePersen = 0.5,
  });

  bool get isComplete => namaUsaha.trim().isNotEmpty;

  BusinessProfile copyWith({
    String? namaUsaha,
    String? alamatUsaha,
    String? metodePembayaran,
    String? namaBank,
    String? namaAkunBank,
    String? noRekening,
    String? kodeInvoice,
    String? namaKontak,
    String? noKontak,
    int? nextInvoiceSeq,
    double? modalAwalUsaha,
    double? pctReserve,
    double? pctMaintenance,
    double? pctNextBusinessFund,
    int? cashReserveBulan,
    double? pbjtTaxRatePersen,
    double? pphFinalTaxRatePersen,
  }) {
    return BusinessProfile(
      namaUsaha: namaUsaha ?? this.namaUsaha,
      alamatUsaha: alamatUsaha ?? this.alamatUsaha,
      metodePembayaran: metodePembayaran ?? this.metodePembayaran,
      namaBank: namaBank ?? this.namaBank,
      namaAkunBank: namaAkunBank ?? this.namaAkunBank,
      noRekening: noRekening ?? this.noRekening,
      kodeInvoice: kodeInvoice ?? this.kodeInvoice,
      namaKontak: namaKontak ?? this.namaKontak,
      noKontak: noKontak ?? this.noKontak,
      nextInvoiceSeq: nextInvoiceSeq ?? this.nextInvoiceSeq,
      modalAwalUsaha: modalAwalUsaha ?? this.modalAwalUsaha,
      pctReserve: pctReserve ?? this.pctReserve,
      pctMaintenance: pctMaintenance ?? this.pctMaintenance,
      pctNextBusinessFund: pctNextBusinessFund ?? this.pctNextBusinessFund,
      cashReserveBulan: cashReserveBulan ?? this.cashReserveBulan,
      pbjtTaxRatePersen: pbjtTaxRatePersen ?? this.pbjtTaxRatePersen,
      pphFinalTaxRatePersen: pphFinalTaxRatePersen ?? this.pphFinalTaxRatePersen,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'nama_usaha': namaUsaha,
      'alamat_usaha': alamatUsaha,
      'metode_pembayaran': metodePembayaran,
      'nama_bank': namaBank,
      'nama_akun_bank': namaAkunBank,
      'no_rekening': noRekening,
      'kode_invoice': kodeInvoice,
      'nama_kontak': namaKontak,
      'no_kontak': noKontak,
      'next_invoice_seq': nextInvoiceSeq,
      'modal_awal_usaha': modalAwalUsaha,
      'pct_reserve': pctReserve,
      'pct_maintenance': pctMaintenance,
      'pct_next_business_fund': pctNextBusinessFund,
      'cash_reserve_bulan': cashReserveBulan,
      'pbjt_tax_rate_persen': pbjtTaxRatePersen,
      'pph_final_tax_rate_persen': pphFinalTaxRatePersen,
    };
  }

  factory BusinessProfile.fromMap(Map<String, Object?> map) {
    String s(String key) => (map[key] as String?) ?? '';
    return BusinessProfile(
      namaUsaha: s('nama_usaha'),
      alamatUsaha: s('alamat_usaha'),
      metodePembayaran: s('metode_pembayaran').isEmpty ? 'Bank Transfer' : s('metode_pembayaran'),
      namaBank: s('nama_bank'),
      namaAkunBank: s('nama_akun_bank'),
      noRekening: s('no_rekening'),
      kodeInvoice: s('kode_invoice'),
      namaKontak: s('nama_kontak'),
      noKontak: s('no_kontak'),
      nextInvoiceSeq: (map['next_invoice_seq'] as int?) ?? 1,
      modalAwalUsaha: (map['modal_awal_usaha'] as num?)?.toDouble() ?? 0,
      pctReserve: (map['pct_reserve'] as num?)?.toDouble() ?? 1,
      pctMaintenance: (map['pct_maintenance'] as num?)?.toDouble() ?? 1,
      pctNextBusinessFund: (map['pct_next_business_fund'] as num?)?.toDouble() ?? 1.5,
      cashReserveBulan: (map['cash_reserve_bulan'] as int?) ?? 4,
      pbjtTaxRatePersen: (map['pbjt_tax_rate_persen'] as num?)?.toDouble() ?? 10,
      pphFinalTaxRatePersen: (map['pph_final_tax_rate_persen'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
