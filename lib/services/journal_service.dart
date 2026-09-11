import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/journal.dart';
import 'period_sync_service.dart';

/// Mesin jurnal double-entry: bungkus [DatabaseHelper] dengan logika supaya
/// pengguna (yang tidak paham akuntansi) tidak pernah perlu tahu istilah
/// Debit/Kredit -- cukup 3 form sederhana (Kas Masuk, Kas Keluar, Transfer
/// Kas) yang otomatis generate [JournalEntry] + [JournalLine] seimbang (Kas
/// Masuk/Keluar boleh split ke lebih dari satu akun lawan sekaligus, Transfer
/// selalu tepat 2 baris).
///
/// Prinsip desain (lihat blueprint_revisi_mangana.txt Bagian 2): uang masuk
/// TIDAK otomatis dianggap Revenue, uang keluar TIDAK otomatis dianggap
/// Expense -- pengguna selalu memilih "akun lawan" sendiri dari seluruh COA
/// ([kChartOfAccounts]), supaya modal owner/pinjaman/transfer antar rekening
/// sendiri/pelunasan hutang/beli aset/prive tidak salah masuk Laba Rugi.
class JournalService {
  JournalService._internal();
  static final JournalService instance = JournalService._internal();

  final _db = DatabaseHelper.instance;

  /// Kas Masuk (BKM): Dr akun Kas/Bank, Cr akun lawan -- [akunLawan] berupa
  /// Map kode akun -> nominal karena satu transaksi boleh split ke lebih
  /// dari satu akun lawan sekaligus (mis. sebagian pelunasan piutang,
  /// sebagian pendapatan lain-lain).
  Future<JournalEntry> postKasMasuk({
    required DateTime tanggal,
    required String terimaDari,
    required String keterangan,
    required String akunKasBank,
    required Map<String, double> akunLawan,
  }) {
    return _postKasMasukKeluar(
      tanggal: tanggal,
      pihak: terimaDari,
      keterangan: keterangan,
      sumber: JournalSumber.kasMasuk,
      akunKasBank: akunKasBank,
      akunLawan: akunLawan,
      kasBankDebit: true,
    );
  }

  /// Kas Keluar (BKK): Dr akun lawan, Cr akun Kas/Bank -- lihat catatan
  /// [postKasMasuk] soal [akunLawan] boleh lebih dari satu akun.
  Future<JournalEntry> postKasKeluar({
    required DateTime tanggal,
    required String penerima,
    required String keterangan,
    required String akunKasBank,
    required Map<String, double> akunLawan,
  }) {
    return _postKasMasukKeluar(
      tanggal: tanggal,
      pihak: penerima,
      keterangan: keterangan,
      sumber: JournalSumber.kasKeluar,
      akunKasBank: akunKasBank,
      akunLawan: akunLawan,
      kasBankDebit: false,
    );
  }

  Future<JournalEntry> _postKasMasukKeluar({
    required DateTime tanggal,
    required String pihak,
    required String keterangan,
    required String sumber,
    required String akunKasBank,
    required Map<String, double> akunLawan,
    required bool kasBankDebit,
  }) async {
    final total = akunLawan.values.fold(0.0, (a, b) => a + b);
    final entry = JournalEntry(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: sumber,
      pihak: pihak,
      createdAt: DateTime.now(),
    );
    final lines = <JournalLine>[
      JournalLine(
        journalEntryId: 0,
        akunKode: akunKasBank,
        debit: kasBankDebit ? total : 0,
        kredit: kasBankDebit ? 0 : total,
      ),
      for (final e in akunLawan.entries)
        if (e.value > 0)
          JournalLine(
            journalEntryId: 0,
            akunKode: e.key,
            debit: kasBankDebit ? 0 : e.value,
            kredit: kasBankDebit ? e.value : 0,
          ),
    ];
    final saved = await _db.postJournalEntry(entry, lines);
    await PeriodSyncService.instance.syncPeriodsAffectedByDate(saved.tanggal);
    return saved;
  }

  /// Transfer Kas: pindah saldo antar akun kas/bank sendiri. Dr akun tujuan,
  /// Cr akun sumber.
  Future<JournalEntry> postTransferKas({
    required DateTime tanggal,
    required String keterangan,
    required double jumlah,
    required String akunSumber,
    required String akunTujuan,
  }) {
    return _postBalanced(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: JournalSumber.transferKas,
      pihak: '',
      jumlah: jumlah,
      akunDebit: akunTujuan,
      akunKredit: akunSumber,
    );
  }

  Future<JournalEntry> _postBalanced({
    required DateTime tanggal,
    required String keterangan,
    required String sumber,
    required String pihak,
    required double jumlah,
    required String akunDebit,
    required String akunKredit,
  }) async {
    final entry = JournalEntry(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: sumber,
      pihak: pihak,
      createdAt: DateTime.now(),
    );
    final lines = [
      JournalLine(journalEntryId: 0, akunKode: akunDebit, debit: jumlah, kredit: 0),
      JournalLine(journalEntryId: 0, akunKode: akunKredit, debit: 0, kredit: jumlah),
    ];
    final saved = await _db.postJournalEntry(entry, lines);
    await PeriodSyncService.instance.syncPeriodsAffectedByDate(saved.tanggal);
    return saved;
  }

  /// Jurnal Penyesuaian generik 2-baris (Accrued Gaji/Beban, amortisasi
  /// Prepaid, penyesuaian Persediaan/Waste) -- akun Dr/Cr sudah ditentukan
  /// sesuai jenis penyesuaiannya oleh pemanggil (lihat
  /// lib/screens/jurnal_penyesuaian_screen.dart), jumlah dihitung otomatis
  /// atau diisi manual tergantung jenisnya.
  Future<JournalEntry> postPenyesuaian({
    required DateTime tanggal,
    required String keterangan,
    required double jumlah,
    required String akunDebit,
    required String akunKredit,
  }) {
    return _postBalanced(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: JournalSumber.penyesuaian,
      pihak: '',
      jumlah: jumlah,
      akunDebit: akunDebit,
      akunKredit: akunKredit,
    );
  }

  /// Depresiasi bulan berjalan: 1 [JournalEntry] dengan sepasang baris
  /// Dr Beban Depresiasi / Cr Akumulasi Penyusutan untuk TIAP kategori Fixed
  /// Asset Register yang punya penyusutan > 0 pada bulan ini (lihat
  /// [kBebanDepresiasiKode]/[kAkumulasiPenyusutanKode]) -- tetap seimbang
  /// walau lebih dari 2 baris karena tiap pasangan Dr/Cr jumlahnya sama.
  Future<JournalEntry> postDepresiasiPeriode({
    required DateTime tanggal,
    required String keterangan,
    required Map<String, double> penyusutanPerKategori,
  }) async {
    final lines = <JournalLine>[];
    for (final entry in penyusutanPerKategori.entries) {
      if (entry.value <= 0) continue;
      final bebanKode = kBebanDepresiasiKode[entry.key];
      final akumulasiKode = kAkumulasiPenyusutanKode[entry.key];
      if (bebanKode == null || akumulasiKode == null) continue;
      lines.add(JournalLine(journalEntryId: 0, akunKode: bebanKode, debit: entry.value, kredit: 0));
      lines.add(JournalLine(journalEntryId: 0, akunKode: akumulasiKode, debit: 0, kredit: entry.value));
    }
    final journalEntry = JournalEntry(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: JournalSumber.penyesuaian,
      pihak: '',
      createdAt: DateTime.now(),
    );
    final saved = await _db.postJournalEntry(journalEntry, lines);
    await PeriodSyncService.instance.syncPeriodsAffectedByDate(saved.tanggal);
    return saved;
  }

  /// Settlement QRIS: pencairan saldo QRIS Clearing (10.12) ke akun Bank
  /// dipotong MDR -- 1 [JournalEntry] dengan 3 baris (Dr Bank sejumlah
  /// bersih, Dr Beban MDR QRIS (61.4) sejumlah [jumlahMdr], Cr QRIS Clearing
  /// sejumlah kotor) supaya tetap seimbang. Lihat catatan QRIS di
  /// blueprint_revisi_mangana.txt Bagian 2 -- alur ini yang tidak bisa
  /// dibuat lewat form Kas Masuk/Keluar/Transfer biasa (selalu 2 baris).
  Future<JournalEntry> postSettlementQris({
    required DateTime tanggal,
    required String keterangan,
    required double jumlahKotor,
    required double jumlahMdr,
    required String akunBankTujuan,
  }) async {
    final jumlahBersih = jumlahKotor - jumlahMdr;
    final lines = <JournalLine>[
      JournalLine(journalEntryId: 0, akunKode: akunBankTujuan, debit: jumlahBersih, kredit: 0),
      if (jumlahMdr > 0)
        JournalLine(journalEntryId: 0, akunKode: '61.4', debit: jumlahMdr, kredit: 0),
      JournalLine(journalEntryId: 0, akunKode: '10.12', debit: 0, kredit: jumlahKotor),
    ];
    final entry = JournalEntry(
      tanggal: tanggal,
      keterangan: keterangan,
      sumber: JournalSumber.settlementQris,
      pihak: '',
      createdAt: DateTime.now(),
    );
    final saved = await _db.postJournalEntry(entry, lines);
    await PeriodSyncService.instance.syncPeriodsAffectedByDate(saved.tanggal);
    return saved;
  }

  Future<void> deleteJournalEntry(int id) async {
    final entry = await _db.getJournalEntryById(id);
    await _db.deleteJournalEntry(id);
    if (entry != null) {
      await PeriodSyncService.instance.syncPeriodsAffectedByDate(entry.tanggal);
    }
  }

  Future<List<JournalEntry>> getAllJournalEntries() => _db.getAllJournalEntries();

  Future<List<JournalLine>> getLinesForEntry(int journalEntryId) =>
      _db.getJournalLinesForEntry(journalEntryId);

  /// Kode akun (dari [kChartOfAccounts]) yang punya minimal 1 transaksi --
  /// dipakai sebagai daftar akun di layar Buku Besar (akun tanpa transaksi
  /// tidak perlu ditampilkan).
  Future<List<String>> getAccountsWithTransactions() async {
    final rows = await _db.getTrialBalanceRaw();
    final kodes = rows.map((r) => r['akun_kode'] as String).toList();
    kodes.sort((a, b) => _coaOrder(a).compareTo(_coaOrder(b)));
    return kodes;
  }

  /// Kartu Buku Besar satu akun: list transaksi kronologis + saldo berjalan.
  /// Saldo berjalan dihitung sesuai saldo normal akun ([Account.isDebitNormal])
  /// -- akun Aset/HPP/Beban bertambah di Debit, akun Liabilitas/Ekuitas/
  /// Pendapatan bertambah di Kredit.
  Future<List<LedgerRow>> getLedgerForAccount(String akunKode) async {
    final account = findAccount(akunKode);
    final isDebitNormal = account?.isDebitNormal ?? true;
    final rows = await _db.getJournalLinesForAccount(akunKode);

    var saldo = 0.0;
    final result = <LedgerRow>[];
    for (final r in rows) {
      final debit = (r['debit'] as num?)?.toDouble() ?? 0;
      final kredit = (r['kredit'] as num?)?.toDouble() ?? 0;
      saldo += isDebitNormal ? (debit - kredit) : (kredit - debit);
      result.add(LedgerRow(
        journalEntryId: r['journal_entry_id'] as int,
        tanggal: DateTime.parse(r['tanggal'] as String),
        keterangan: r['keterangan'] as String? ?? '',
        sumber: r['sumber'] as String? ?? '',
        pihak: r['pihak'] as String? ?? '',
        debit: debit,
        kredit: kredit,
        saldoBerjalan: saldo,
      ));
    }
    return result;
  }

  /// Saldo berjalan akun per tanggal [asOf] (inklusif) -- dipakai layar
  /// Rekonsiliasi Bank untuk ambil "Saldo Buku (GL)" di tanggal cutoff.
  /// 0 kalau belum ada transaksi sampai tanggal itu.
  Future<double> getSaldoGlAsOf(String akunKode, DateTime asOf) async {
    final rows = await getLedgerForAccount(akunKode);
    final upToDate = rows.where((r) => !r.tanggal.isAfter(asOf));
    if (upToDate.isEmpty) return 0;
    return upToDate.last.saldoBerjalan;
  }

  /// Neraca Saldo (GL): daftar SEMUA akun yang punya transaksi dari
  /// journal_lines, dengan saldo ditampilkan di sisi normalnya (mis. akun
  /// Aset yang totalnya net-debit tampil di kolom Debit). Total debit &
  /// kredit harus selalu sama karena tiap posting sudah seimbang.
  Future<List<TrialBalanceRow>> getTrialBalanceFromGl() async {
    final rows = await _db.getTrialBalanceRaw();
    final result = <TrialBalanceRow>[];
    for (final r in rows) {
      final kode = r['akun_kode'] as String;
      final account = findAccount(kode);
      final totalDebit = (r['total_debit'] as num?)?.toDouble() ?? 0;
      final totalKredit = (r['total_kredit'] as num?)?.toDouble() ?? 0;
      final isDebitNormal = account?.isDebitNormal ?? true;
      final net = isDebitNormal ? (totalDebit - totalKredit) : (totalKredit - totalDebit);
      result.add(TrialBalanceRow(
        akunKode: kode,
        akunNama: account?.nama ?? kode,
        debit: isDebitNormal ? (net > 0 ? net : 0) : (net < 0 ? -net : 0),
        kredit: isDebitNormal ? (net < 0 ? -net : 0) : (net > 0 ? net : 0),
      ));
    }
    result.sort((a, b) => _coaOrder(a.akunKode).compareTo(_coaOrder(b.akunKode)));
    return result;
  }
}

/// Index akun di [kChartOfAccounts] -- dipakai untuk urutkan daftar akun
/// sesuai urutan COA (bukan urutan string kode, yang salah untuk kasus
/// seperti "10.10" < "10.2"). Akun yang entah kenapa sudah tidak ada lagi di
/// COA (mis. dihapus setelah pernah dipakai) ditaruh di akhir.
int _coaOrder(String kode) {
  final i = kChartOfAccounts.indexWhere((a) => a.kode == kode);
  return i < 0 ? kChartOfAccounts.length : i;
}
