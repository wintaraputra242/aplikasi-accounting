import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/period.dart';

/// Menjaga field-field [Period] yang punya sumber data jelas di Chart of
/// Akun (lib/models/account.dart) tetap sinkron dengan transaksi Kas/Jurnal
/// (journal_entries/journal_lines) -- dipanggil otomatis oleh
/// [JournalService] setiap kali ada jurnal baru/dihapus, TIDAK lewat tombol
/// manual (beda dengan pola [StockEditor.syncToPeriod] yang manual by
/// design). Field tetap bisa diedit manual di UI, tapi akan ditimpa lagi
/// begitu ada jurnal baru yang relevan disimpan/dihapus.
///
/// Field yang di luar pemetaan di sini (mis. Hutang PPh23/Pajak
/// Badan/Service Charge/Lain-lain, Tax Paid/Fund, breakdown Penjualan per
/// channel bayar, Saldo Awal/Pembelian/Persediaan/Waste) SENGAJA tidak
/// disentuh karena tidak ada akun COA 1:1 untuk field-field itu (lihat
/// plan sinkronisasi Kas->Periode).
class PeriodSyncService {
  PeriodSyncService._internal();
  static final PeriodSyncService instance = PeriodSyncService._internal();

  final _db = DatabaseHelper.instance;

  /// Sinkronkan ulang semua Period yang terdampak oleh jurnal bertanggal
  /// [tanggal] (baru dibuat atau baru dihapus).
  Future<void> syncPeriodsAffectedByDate(DateTime tanggal) async {
    final periods = await _db.getAllPeriods();
    final cutoff = _dateOnly(tanggal);

    for (final period in periods) {
      final needsFlow = _inRange(tanggal, period.startDate, period.endDate);
      // Saldo akhir bersifat kumulatif dari awal, jadi periode ini DAN semua
      // periode sesudahnya (endDate >= tanggal transaksi) ikut terdampak.
      final needsBalance = !period.endDate.isBefore(cutoff);
      if (!needsFlow && !needsBalance) continue;

      var updated = period;
      if (needsFlow) updated = await _withFlowFields(updated);
      if (needsBalance) updated = await _withBalanceFields(updated);
      await _db.updatePeriod(updated);
    }
  }

  // --- Flow fields: total transaksi DALAM rentang tanggal periode ---

  Future<Period> _withFlowFields(Period p) async {
    final s = p.startDate, e = p.endDate;
    final bebanSewa = await _flowNet('61.16', s, e);

    return p.copyWith(
      bebanGajiKaryawan: await _flowNet('61.1', s, e),
      bebanListrikBulanan: await _flowNet('61.2', s, e),
      bebanSuppliesCleaning: await _flowNet('61.3', s, e),
      bebanMdrQris: await _flowNet('61.4', s, e),
      bebanMdrEdc: await _flowNet('61.5', s, e),
      bebanMdrEsb: await _flowNet('61.6', s, e),
      bebanMdrGofood: await _flowNet('61.7', s, e),
      bebanMdrGrabfood: await _flowNet('61.8', s, e),
      bebanMarketing: await _flowNet('61.9', s, e),
      bebanAdmTransfer: await _flowNet('61.10', s, e),
      bebanKartuDebit: await _flowNet('61.11', s, e),
      bebanAdminRekening: await _flowNet('61.12', s, e),
      bebanPajakRekening: await _flowNet('61.13', s, e),
      bebanBiayaAkomodasi: await _flowNet('61.14', s, e),
      bebanBiayaServiceKaryawan: await _flowNet('61.15', s, e),
      bebanPenyusutanBar: await _flowNet('61.17', s, e),
      bebanPenyusutanKitchen: await _flowNet('61.18', s, e),
      bebanPenyusutanFurnitureArea: await _flowNet('61.19', s, e),
      bebanPenyusutanOffice: await _flowNet('61.20', s, e),
      bebanLainLain: await _flowNet('61.21', s, e),
      pendapatanBunga: await _flowNet('40.4', s, e),
      modalDisetorPeriodeIni: await _flowNet('30.1', s, e),
      privePeriodeIni: await _flowNet('32.1', s, e),
      customExpenseItems: _upsertCustomItem(
        p.customExpenseItems,
        id: 'sync-beban-sewa',
        label: 'Beban Sewa',
        value: bebanSewa,
      ),
    );
  }

  // --- Balance fields: saldo akhir AS OF endDate periode (kumulatif) ---

  Future<Period> _withBalanceFields(Period p) async {
    final asOf = p.endDate;

    var kasBankItems = p.kasBankItems;
    for (final akun in kAkunKasBank) {
      final saldo = await _balanceAsOf(akun.kode, asOf);
      kasBankItems = _upsertCustomItem(
        kasBankItems,
        id: 'sync-${akun.kode}',
        label: akun.nama,
        value: saldo,
      );
    }

    return p.copyWith(
      piutangUsaha: await _balanceAsOf('10.11', asOf),
      bebanDibayarDimuka: await _balanceAsOf('13.5', asOf),
      hutangUsaha: await _balanceAsOf('20.1', asOf) + await _balanceAsOf('20.100', asOf),
      hutangGajiKaryawan: await _balanceAsOf('20.101', asOf),
      hutangPb1: await _balanceAsOf('20.104', asOf),
      hutangPph21: await _balanceAsOf('20.2', asOf),
      pendapatanDiterimaDimuka: await _balanceAsOf('20.103', asOf),
      pinjaman: await _balanceAsOf('21.1', asOf) + await _balanceAsOf('21.2', asOf),
      kasBankItems: kasBankItems,
    );
  }

  // --- Helper hitung dari journal_lines ---

  /// Net flow satu akun dalam rentang tanggal [start]..[end] (inklusif),
  /// bertanda sesuai saldo normal akun ([Account.isDebitNormal]).
  Future<double> _flowNet(String kode, DateTime start, DateTime end) async {
    final rows = await _db.getJournalLinesForAccount(kode);
    final isDebitNormal = findAccount(kode)?.isDebitNormal ?? true;
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    var net = 0.0;
    for (final r in rows) {
      final tgl = DateTime.parse(r['tanggal'] as String);
      if (tgl.isBefore(s) || tgl.isAfter(e)) continue;
      final debit = (r['debit'] as num?)?.toDouble() ?? 0;
      final kredit = (r['kredit'] as num?)?.toDouble() ?? 0;
      net += isDebitNormal ? (debit - kredit) : (kredit - debit);
    }
    return net;
  }

  /// Saldo berjalan satu akun per tanggal [asOf] (inklusif, dari SELURUH
  /// histori), bertanda sesuai saldo normal akun.
  Future<double> _balanceAsOf(String kode, DateTime asOf) async {
    final rows = await _db.getJournalLinesForAccount(kode);
    final isDebitNormal = findAccount(kode)?.isDebitNormal ?? true;
    final cutoff = _dateOnly(asOf);
    var net = 0.0;
    for (final r in rows) {
      final tgl = DateTime.parse(r['tanggal'] as String);
      if (tgl.isAfter(cutoff)) continue;
      final debit = (r['debit'] as num?)?.toDouble() ?? 0;
      final kredit = (r['kredit'] as num?)?.toDouble() ?? 0;
      net += isDebitNormal ? (debit - kredit) : (kredit - debit);
    }
    return net;
  }

  /// Tambah/perbarui/hapus 1 item bertanda tetap [id] di dalam list
  /// [CustomLineItem] tanpa mengganggu item lain yang ditambah manual oleh
  /// user. Item dihapus kalau [value] jadi 0 (mis. transaksi sumbernya
  /// dihapus) supaya tidak menyisakan baris kosong.
  List<CustomLineItem> _upsertCustomItem(
    List<CustomLineItem> items, {
    required String id,
    required String label,
    required double value,
  }) {
    final idx = items.indexWhere((i) => i.id == id);
    if (value == 0) {
      if (idx < 0) return items;
      final updated = [...items]..removeAt(idx);
      return updated;
    }
    if (idx < 0) {
      return [...items, CustomLineItem(id: id, label: label, value: value)];
    }
    final updated = [...items];
    updated[idx] = updated[idx].copyWith(label: label, value: value);
    return updated;
  }

  bool _inRange(DateTime d, DateTime start, DateTime end) {
    final x = _dateOnly(d);
    return !x.isBefore(_dateOnly(start)) && !x.isAfter(_dateOnly(end));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
