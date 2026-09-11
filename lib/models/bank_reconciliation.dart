/// Model untuk Rekonsiliasi Bank -- susulan setelah Jurnal Penyesuaian
/// selesai (blueprint_revisi_mangana.txt Bagian 2 item 7, belum ada desain
/// konkret di blueprint aslinya). Desain di sini pakai worksheet rekonsiliasi
/// 2 kolom standar (Saldo Buku vs Saldo Rekening Koran) -- bukan
/// dipaksa sama dengan mencatat "selisih" sebagai beban, tapi ditelusuri
/// lewat 4 jenis item penyesuaian ([BankReconTipe]). Kalau nanti ada revisi
/// dari istri pengguna soal alur/format ini, tinggal disesuaikan di sini.
library;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateFromIso(String s) => DateTime.parse(s);

/// Jenis item penyesuaian rekonsiliasi. [outstandingTransfer] &
/// [depositInTransit] adalah beda waktu (SUDAH tercatat di buku, belum
/// "settle" di bank) -- tidak perlu diposting ke jurnal, cukup ditelusuri
/// sampai clear di rekonsiliasi bulan berikutnya. [bankCharge] & [bungaBank]
/// adalah transaksi yang SUDAH terjadi di bank tapi BELUM tercatat di buku
/// -- ini yang perlu diposting ke Jurnal Penyesuaian supaya buku akurat.
class BankReconTipe {
  static const outstandingTransfer = 'Outstanding Transfer/Cek';
  static const depositInTransit = 'Deposit in Transit';
  static const bankCharge = 'Biaya Bank Belum Tercatat';
  static const bungaBank = 'Bunga Bank Belum Tercatat';

  static const all = [outstandingTransfer, depositInTransit, bankCharge, bungaBank];

  /// Item yang perlu diposting ke Jurnal Penyesuaian supaya buku sinkron
  /// dengan bank (beda dengan outstanding/deposit in transit yang murni
  /// beda waktu).
  static bool needsPosting(String tipe) => tipe == bankCharge || tipe == bungaBank;
}

class BankReconciliation {
  final int? id;
  final String akunKode;
  final DateTime tanggalCutoff;
  final double saldoRekeningKoran;
  final String catatan;
  final DateTime createdAt;

  const BankReconciliation({
    this.id,
    required this.akunKode,
    required this.tanggalCutoff,
    this.saldoRekeningKoran = 0,
    this.catatan = '',
    required this.createdAt,
  });

  BankReconciliation copyWith({double? saldoRekeningKoran, String? catatan}) => BankReconciliation(
        id: id,
        akunKode: akunKode,
        tanggalCutoff: tanggalCutoff,
        saldoRekeningKoran: saldoRekeningKoran ?? this.saldoRekeningKoran,
        catatan: catatan ?? this.catatan,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'akun_kode': akunKode,
        'tanggal_cutoff': _isoDate(tanggalCutoff),
        'saldo_rekening_koran': saldoRekeningKoran,
        'catatan': catatan,
        'created_at': createdAt.toIso8601String(),
      };

  factory BankReconciliation.fromMap(Map<String, Object?> map) => BankReconciliation(
        id: map['id'] as int?,
        akunKode: map['akun_kode'] as String,
        tanggalCutoff: _dateFromIso(map['tanggal_cutoff'] as String),
        saldoRekeningKoran: (map['saldo_rekening_koran'] as num?)?.toDouble() ?? 0,
        catatan: map['catatan'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BankReconciliationItem {
  final int? id;
  final int reconciliationId;
  final String tipe; // salah satu dari BankReconTipe
  final String keterangan;
  final double jumlah;
  /// Hanya relevan untuk tipe yang [BankReconTipe.needsPosting] -- true
  /// kalau sudah diposting ke Jurnal Penyesuaian.
  final bool posted;
  final int? journalEntryId;

  const BankReconciliationItem({
    this.id,
    required this.reconciliationId,
    required this.tipe,
    this.keterangan = '',
    this.jumlah = 0,
    this.posted = false,
    this.journalEntryId,
  });

  BankReconciliationItem copyWith({
    String? tipe,
    String? keterangan,
    double? jumlah,
    bool? posted,
    int? journalEntryId,
  }) =>
      BankReconciliationItem(
        id: id,
        reconciliationId: reconciliationId,
        tipe: tipe ?? this.tipe,
        keterangan: keterangan ?? this.keterangan,
        jumlah: jumlah ?? this.jumlah,
        posted: posted ?? this.posted,
        journalEntryId: journalEntryId ?? this.journalEntryId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'reconciliation_id': reconciliationId,
        'tipe': tipe,
        'keterangan': keterangan,
        'jumlah': jumlah,
        'posted': posted ? 1 : 0,
        'journal_entry_id': journalEntryId,
      };

  factory BankReconciliationItem.fromMap(Map<String, Object?> map) => BankReconciliationItem(
        id: map['id'] as int?,
        reconciliationId: map['reconciliation_id'] as int,
        tipe: map['tipe'] as String,
        keterangan: map['keterangan'] as String? ?? '',
        jumlah: (map['jumlah'] as num?)?.toDouble() ?? 0,
        posted: ((map['posted'] as int?) ?? 0) != 0,
        journalEntryId: map['journal_entry_id'] as int?,
      );
}

/// Ringkasan hasil hitung rekonsiliasi -- formula 2 kolom standar:
///   Saldo Buku (GL) + Bunga Belum Tercatat - Biaya Bank Belum Tercatat
///     = Saldo Buku Disesuaikan
///   Saldo Rekening Koran + Deposit in Transit - Outstanding Transfer/Cek
///     = Saldo Bank Disesuaikan
/// Rekonsiliasi berhasil kalau kedua "saldo disesuaikan" itu sama
/// ([selisih] = 0).
class BankReconSummary {
  final double saldoBuku;
  final double bungaBelumTercatat;
  final double biayaBelumTercatat;
  final double saldoBukuDisesuaikan;

  final double saldoRekeningKoran;
  final double depositInTransit;
  final double outstandingTransfer;
  final double saldoBankDisesuaikan;

  final double selisih;

  const BankReconSummary({
    required this.saldoBuku,
    required this.bungaBelumTercatat,
    required this.biayaBelumTercatat,
    required this.saldoBukuDisesuaikan,
    required this.saldoRekeningKoran,
    required this.depositInTransit,
    required this.outstandingTransfer,
    required this.saldoBankDisesuaikan,
    required this.selisih,
  });

  bool get balanced => selisih.abs() < 1;
}

BankReconSummary buildBankReconSummary({
  required double saldoBuku,
  required double saldoRekeningKoran,
  required List<BankReconciliationItem> items,
}) {
  double sumTipe(String tipe) =>
      items.where((i) => i.tipe == tipe).fold(0.0, (a, i) => a + i.jumlah);

  final bunga = sumTipe(BankReconTipe.bungaBank);
  final biaya = sumTipe(BankReconTipe.bankCharge);
  final deposit = sumTipe(BankReconTipe.depositInTransit);
  final outstanding = sumTipe(BankReconTipe.outstandingTransfer);

  final saldoBukuDisesuaikan = saldoBuku + bunga - biaya;
  final saldoBankDisesuaikan = saldoRekeningKoran + deposit - outstanding;

  return BankReconSummary(
    saldoBuku: saldoBuku,
    bungaBelumTercatat: bunga,
    biayaBelumTercatat: biaya,
    saldoBukuDisesuaikan: saldoBukuDisesuaikan,
    saldoRekeningKoran: saldoRekeningKoran,
    depositInTransit: deposit,
    outstandingTransfer: outstanding,
    saldoBankDisesuaikan: saldoBankDisesuaikan,
    selisih: saldoBukuDisesuaikan - saldoBankDisesuaikan,
  );
}
