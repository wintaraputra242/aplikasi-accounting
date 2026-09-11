/// Model untuk Jurnal Umum + Buku Besar (double-entry). Satu [JournalEntry]
/// dibuat otomatis oleh salah satu dari 3 form transaksi sederhana (Kas
/// Masuk/Kas Keluar/Transfer Kas, lihat lib/services/journal_service.dart --
/// TIDAK ada layar input jurnal manual mentah Debit/Kredit), masing-masing
/// selalu diikuti tepat 2 [JournalLine] yang seimbang (total debit = total
/// kredit).
library;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateFromIso(String s) => DateTime.parse(s);

/// Sumber transaksi yang men-generate [JournalEntry] ini.
class JournalSumber {
  static const kasMasuk = 'Kas Masuk';
  static const kasKeluar = 'Kas Keluar';
  static const transferKas = 'Transfer Kas';
  /// Jurnal Penyesuaian (Adjusting Entries) -- depresiasi, accrued
  /// salary/expense, amortisasi prepaid, penyesuaian persediaan/waste.
  static const penyesuaian = 'Penyesuaian';
  /// Settlement QRIS: pencairan saldo QRIS Clearing ke Bank dipotong MDR --
  /// 3 baris (Dr Bank, Dr Beban MDR, Cr QRIS Clearing), lihat catatan QRIS
  /// di blueprint_revisi_mangana.txt Bagian 2.
  static const settlementQris = 'Settlement QRIS';
}

class JournalEntry {
  final int? id;
  final DateTime tanggal;
  final String keterangan;
  final String sumber; // salah satu dari JournalSumber
  /// "Terima Dari" (Kas Masuk) / "Penerima" (Kas Keluar) -- kosong untuk
  /// Transfer Kas.
  final String pihak;
  final DateTime createdAt;

  const JournalEntry({
    this.id,
    required this.tanggal,
    required this.keterangan,
    required this.sumber,
    this.pihak = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'tanggal': _isoDate(tanggal),
        'keterangan': keterangan,
        'sumber': sumber,
        'pihak': pihak,
        'created_at': createdAt.toIso8601String(),
      };

  factory JournalEntry.fromMap(Map<String, Object?> map) => JournalEntry(
        id: map['id'] as int?,
        tanggal: _dateFromIso(map['tanggal'] as String),
        keterangan: map['keterangan'] as String? ?? '',
        sumber: map['sumber'] as String? ?? '',
        pihak: map['pihak'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class JournalLine {
  final int? id;
  final int journalEntryId;
  final String akunKode;
  final double debit;
  final double kredit;

  const JournalLine({
    this.id,
    required this.journalEntryId,
    required this.akunKode,
    this.debit = 0,
    this.kredit = 0,
  });

  /// Dipakai saat posting: baris dibuat dengan [journalEntryId] placeholder
  /// (0) sebelum id entry induknya diketahui, lalu diisi id sebenarnya di
  /// sini tepat sebelum insert -- lihat [DatabaseHelper.postJournalEntry].
  JournalLine copyWithEntryId(int journalEntryId) => JournalLine(
        journalEntryId: journalEntryId,
        akunKode: akunKode,
        debit: debit,
        kredit: kredit,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'journal_entry_id': journalEntryId,
        'akun_kode': akunKode,
        'debit': debit,
        'kredit': kredit,
      };

  factory JournalLine.fromMap(Map<String, Object?> map) => JournalLine(
        id: map['id'] as int?,
        journalEntryId: map['journal_entry_id'] as int,
        akunKode: map['akun_kode'] as String,
        debit: (map['debit'] as num?)?.toDouble() ?? 0,
        kredit: (map['kredit'] as num?)?.toDouble() ?? 0,
      );
}

/// Satu baris di kartu Buku Besar suatu akun: gabungan info [JournalEntry] +
/// [JournalLine] miliknya, plus saldo berjalan yang sudah dihitung
/// [JournalService.getLedgerForAccount].
class LedgerRow {
  final int journalEntryId;
  final DateTime tanggal;
  final String keterangan;
  final String sumber;
  final String pihak;
  final double debit;
  final double kredit;
  final double saldoBerjalan;

  const LedgerRow({
    required this.journalEntryId,
    required this.tanggal,
    required this.keterangan,
    required this.sumber,
    required this.pihak,
    required this.debit,
    required this.kredit,
    required this.saldoBerjalan,
  });
}

/// Satu baris di Neraca Saldo (dari GL): total debit/kredit satu akun dari
/// seluruh journal_lines.
class TrialBalanceRow {
  final String akunKode;
  final String akunNama;
  final double debit;
  final double kredit;

  const TrialBalanceRow({
    required this.akunKode,
    required this.akunNama,
    required this.debit,
    required this.kredit,
  });
}
