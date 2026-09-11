import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/bank_reconciliation.dart';
import '../models/barang.dart';
import '../models/business_profile.dart';
import '../models/fixed_asset.dart';
import '../models/invoice_record.dart';
import '../models/journal.dart';
import '../models/period.dart';

const _createPeriodsTableSql = '''
  CREATE TABLE periods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_type TEXT NOT NULL DEFAULT 'calendar',
    month INTEGER,
    year INTEGER,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    custom_label TEXT,
    penjualan_cash REAL NOT NULL DEFAULT 0,
    penjualan_qris_mandiri REAL NOT NULL DEFAULT 0,
    penjualan_edc_on_us REAL NOT NULL DEFAULT 0,
    penjualan_edc_off_us REAL NOT NULL DEFAULT 0,
    penjualan_gofood REAL NOT NULL DEFAULT 0,
    penjualan_grabfood REAL NOT NULL DEFAULT 0,
    penjualan_qris_esb REAL NOT NULL DEFAULT 0,
    penjualan_other REAL NOT NULL DEFAULT 0,
    pendapatan_bunga REAL NOT NULL DEFAULT 0,
    saldo_awal REAL NOT NULL DEFAULT 0,
    total_pembelian_bahan_baku REAL NOT NULL DEFAULT 0,
    persediaan_akhir REAL NOT NULL DEFAULT 0,
    beban_gaji_karyawan REAL NOT NULL DEFAULT 0,
    beban_listrik_bulanan REAL NOT NULL DEFAULT 0,
    beban_listrik_dua_mingguan REAL NOT NULL DEFAULT 0,
    beban_ipl REAL NOT NULL DEFAULT 0,
    beban_supplies_cleaning REAL NOT NULL DEFAULT 0,
    beban_mdr_qris REAL NOT NULL DEFAULT 0,
    beban_mdr_edc REAL NOT NULL DEFAULT 0,
    beban_mdr_esb REAL NOT NULL DEFAULT 0,
    beban_mdr_gofood REAL NOT NULL DEFAULT 0,
    beban_mdr_grabfood REAL NOT NULL DEFAULT 0,
    beban_marketing REAL NOT NULL DEFAULT 0,
    beban_adm_transfer REAL NOT NULL DEFAULT 0,
    beban_kartu_debit REAL NOT NULL DEFAULT 0,
    beban_admin_rekening REAL NOT NULL DEFAULT 0,
    beban_pajak_rekening REAL NOT NULL DEFAULT 0,
    beban_lain_lain REAL NOT NULL DEFAULT 0,
    beban_biaya_akomodasi REAL NOT NULL DEFAULT 0,
    beban_biaya_service_karyawan REAL NOT NULL DEFAULT 0,
    beban_penyusutan_bar REAL NOT NULL DEFAULT 0,
    beban_penyusutan_kitchen REAL NOT NULL DEFAULT 0,
    beban_penyusutan_furniture_area REAL NOT NULL DEFAULT 0,
    custom_income_items TEXT NOT NULL DEFAULT '[]',
    custom_expense_items TEXT NOT NULL DEFAULT '[]',
    beban_waste_bahan_baku REAL NOT NULL DEFAULT 0,
    beban_penyusutan_office REAL NOT NULL DEFAULT 0,
    kas_bank_items TEXT NOT NULL DEFAULT '[]',
    piutang_usaha REAL NOT NULL DEFAULT 0,
    beban_dibayar_dimuka REAL NOT NULL DEFAULT 0,
    custom_current_asset_items TEXT NOT NULL DEFAULT '[]',
    hutang_usaha REAL NOT NULL DEFAULT 0,
    hutang_gaji_karyawan REAL NOT NULL DEFAULT 0,
    hutang_pb1 REAL NOT NULL DEFAULT 0,
    hutang_pph21 REAL NOT NULL DEFAULT 0,
    hutang_pph23 REAL NOT NULL DEFAULT 0,
    hutang_pajak_badan REAL NOT NULL DEFAULT 0,
    hutang_service_charge REAL NOT NULL DEFAULT 0,
    hutang_lain_lain REAL NOT NULL DEFAULT 0,
    pendapatan_diterima_dimuka REAL NOT NULL DEFAULT 0,
    pinjaman REAL NOT NULL DEFAULT 0,
    custom_liability_items TEXT NOT NULL DEFAULT '[]',
    pbjt_tax_paid REAL NOT NULL DEFAULT 0,
    pbjt_tax_fund REAL NOT NULL DEFAULT 0,
    pph_final_tax_paid REAL NOT NULL DEFAULT 0,
    pph_final_tax_fund REAL NOT NULL DEFAULT 0,
    modal_disetor_periode_ini REAL NOT NULL DEFAULT 0,
    prive_periode_ini REAL NOT NULL DEFAULT 0,
    sc_terkumpul REAL NOT NULL DEFAULT 0
  )
''';

const _createFixedAssetsTableSql = '''
  CREATE TABLE fixed_assets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kode TEXT NOT NULL DEFAULT '',
    nama TEXT NOT NULL,
    kategori TEXT NOT NULL DEFAULT 'Kitchen',
    lokasi TEXT NOT NULL DEFAULT '',
    tanggal_beli TEXT NOT NULL,
    harga_perolehan REAL NOT NULL DEFAULT 0,
    umur_tahun INTEGER NOT NULL DEFAULT 1,
    aktif INTEGER NOT NULL DEFAULT 1,
    alasan_nonaktif TEXT NOT NULL DEFAULT '',
    tanggal_nonaktif TEXT
  )
''';

const _createBarangItemsTableSql = '''
  CREATE TABLE barang_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kode TEXT NOT NULL DEFAULT '',
    nama TEXT NOT NULL,
    kategori TEXT NOT NULL DEFAULT 'Kitchen',
    satuan TEXT NOT NULL DEFAULT '',
    harga_rata_rata REAL NOT NULL DEFAULT 0,
    aktif INTEGER NOT NULL DEFAULT 1
  )
''';

const _createPembelianItemsTableSql = '''
  CREATE TABLE pembelian_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_id INTEGER NOT NULL,
    barang_id INTEGER NOT NULL,
    tanggal TEXT NOT NULL,
    qty REAL NOT NULL DEFAULT 0,
    harga_satuan REAL NOT NULL DEFAULT 0,
    keterangan TEXT NOT NULL DEFAULT ''
  )
''';

const _createWasteItemsTableSql = '''
  CREATE TABLE waste_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_id INTEGER NOT NULL,
    barang_id INTEGER NOT NULL,
    tanggal TEXT NOT NULL,
    qty REAL NOT NULL DEFAULT 0,
    alasan TEXT NOT NULL DEFAULT '',
    nilai_rupiah REAL NOT NULL DEFAULT 0,
    keterangan TEXT NOT NULL DEFAULT ''
  )
''';

const _createStockOpnameTableSql = '''
  CREATE TABLE stock_opname (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_id INTEGER NOT NULL,
    barang_id INTEGER NOT NULL,
    stok_awal REAL NOT NULL DEFAULT 0,
    stok_fisik REAL NOT NULL DEFAULT 0
  )
''';

const _createBusinessProfileTableSql = '''
  CREATE TABLE business_profile (
    id INTEGER PRIMARY KEY,
    nama_usaha TEXT NOT NULL DEFAULT '',
    alamat_usaha TEXT NOT NULL DEFAULT '',
    metode_pembayaran TEXT NOT NULL DEFAULT 'Bank Transfer',
    nama_bank TEXT NOT NULL DEFAULT '',
    nama_akun_bank TEXT NOT NULL DEFAULT '',
    no_rekening TEXT NOT NULL DEFAULT '',
    kode_invoice TEXT NOT NULL DEFAULT '',
    nama_kontak TEXT NOT NULL DEFAULT '',
    no_kontak TEXT NOT NULL DEFAULT '',
    next_invoice_seq INTEGER NOT NULL DEFAULT 1,
    modal_awal_usaha REAL NOT NULL DEFAULT 0,
    pct_reserve REAL NOT NULL DEFAULT 1,
    pct_maintenance REAL NOT NULL DEFAULT 1,
    pct_next_business_fund REAL NOT NULL DEFAULT 1.5,
    cash_reserve_bulan INTEGER NOT NULL DEFAULT 4,
    pbjt_tax_rate_persen REAL NOT NULL DEFAULT 10,
    pph_final_tax_rate_persen REAL NOT NULL DEFAULT 0.5
  )
''';

const _createInvoicesTableSql = '''
  CREATE TABLE invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    no_invoice TEXT NOT NULL,
    tanggal_invoice TEXT NOT NULL,
    jatuh_tempo TEXT NOT NULL,
    nama_penerima TEXT NOT NULL,
    alamat_penerima TEXT NOT NULL DEFAULT '',
    items_json TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
''';

const _createJournalEntriesTableSql = '''
  CREATE TABLE journal_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tanggal TEXT NOT NULL,
    keterangan TEXT NOT NULL DEFAULT '',
    sumber TEXT NOT NULL,
    pihak TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  )
''';

const _createJournalLinesTableSql = '''
  CREATE TABLE journal_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    journal_entry_id INTEGER NOT NULL,
    akun_kode TEXT NOT NULL,
    debit REAL NOT NULL DEFAULT 0,
    kredit REAL NOT NULL DEFAULT 0
  )
''';

const _createBankReconciliationsTableSql = '''
  CREATE TABLE bank_reconciliations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    akun_kode TEXT NOT NULL,
    tanggal_cutoff TEXT NOT NULL,
    saldo_rekening_koran REAL NOT NULL DEFAULT 0,
    catatan TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  )
''';

const _createBankReconciliationItemsTableSql = '''
  CREATE TABLE bank_reconciliation_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reconciliation_id INTEGER NOT NULL,
    tipe TEXT NOT NULL,
    keterangan TEXT NOT NULL DEFAULT '',
    jumlah REAL NOT NULL DEFAULT 0,
    posted INTEGER NOT NULL DEFAULT 0,
    journal_entry_id INTEGER
  )
''';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Wrapper akses database SQLite lokal untuk menyimpan data tiap periode
/// pembukuan: penjualan, pembelian, dan beban -- ditambah profil usaha dan
/// riwayat invoice yang sudah pernah digenerate.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;
  static String? _dbPath;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Lokasi file database di disk -- dipakai untuk fitur backup.
  Future<String> get databasePath async {
    await database; // pastikan _dbPath sudah terisi
    return _dbPath!;
  }

  /// Tutup koneksi database yang sedang aktif supaya file-nya bisa ditimpa
  /// dengan aman -- dipakai oleh fitur Restore Database sebelum file backup
  /// yang dipilih user menggantikan file database saat ini. Panggilan
  /// berikutnya ke [database] akan otomatis membuka ulang file yang baru.
  Future<void> closeDatabase() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  Future<Database> _initDb() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, 'aplikasi_accounting.db');
    _dbPath = path;
    return openDatabase(
      path,
      version: 15,
      onCreate: (db, version) async {
        await db.execute(_createPeriodsTableSql);
        await db.execute(_createBusinessProfileTableSql);
        await db.execute(_createInvoicesTableSql);
        await db.execute(_createBarangItemsTableSql);
        await db.execute(_createPembelianItemsTableSql);
        await db.execute(_createWasteItemsTableSql);
        await db.execute(_createStockOpnameTableSql);
        await db.execute(_createFixedAssetsTableSql);
        await db.execute(_createJournalEntriesTableSql);
        await db.execute(_createJournalLinesTableSql);
        await db.execute(_createBankReconciliationsTableSql);
        await db.execute(_createBankReconciliationItemsTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 hanya mengenal periode per bulan kalender (kolom month/year,
          // tanpa start_date/end_date/period_type). Migrasikan ke skema baru
          // yang juga mendukung rentang tanggal custom. _createPeriodsTableSql
          // sekarang sudah memakai skema v5, jadi migrasi v1 ini menulis ke
          // kolom v3 (beban_listrik_bulanan) dan v5 (penjualan_qris_mandiri/
          // penjualan_edc_on_us) sekaligus supaya data v1 tidak hilang -- versi
          // v3/v4 dari kolom-kolom itu akan dilewati lagi di bawah tanpa efek.
          await db.execute('ALTER TABLE periods RENAME TO periods_old');
          await db.execute(_createPeriodsTableSql);
          final oldRows = await db.query('periods_old');
          for (final row in oldRows) {
            final month = row['month'] as int;
            final year = row['year'] as int;
            final start = DateTime(year, month, 1);
            final end = DateTime(year, month + 1, 0);
            final newRow = <String, Object?>{
              'period_type': 'calendar',
              'start_date': _isoDate(start),
              'end_date': _isoDate(end),
              'custom_label': null,
              'penjualan_cash': row['penjualan_cash'] ?? 0,
              'penjualan_qris_mandiri': row['penjualan_qris'] ?? 0,
              'penjualan_edc_on_us': row['penjualan_edc'] ?? 0,
              'penjualan_grabfood': row['penjualan_grabfood'] ?? 0,
              'penjualan_gofood': row['penjualan_gofood'] ?? 0,
              'saldo_awal': row['saldo_awal'] ?? 0,
              'total_pembelian_bahan_baku': row['total_pembelian_bahan_baku'] ?? 0,
              'persediaan_akhir': row['persediaan_akhir'] ?? 0,
              'beban_gaji_karyawan': row['beban_gaji_karyawan'] ?? 0,
              'beban_listrik_bulanan': row['beban_listrik'] ?? 0,
              'beban_supplies_cleaning': row['beban_supplies_cleaning'] ?? 0,
              'beban_mdr_qris': row['beban_mdr_qris'] ?? 0,
              'beban_mdr_edc': row['beban_mdr_edc'] ?? 0,
              'beban_mdr_esb': row['beban_mdr_esb'] ?? 0,
              'beban_marketing': row['beban_marketing'] ?? 0,
              'beban_adm_transfer': row['beban_adm_transfer'] ?? 0,
              'beban_kartu_debit': row['beban_kartu_debit'] ?? 0,
              'beban_admin_rekening': row['beban_admin_rekening'] ?? 0,
              'beban_pajak_rekening': row['beban_pajak_rekening'] ?? 0,
              'beban_lain_lain': row['beban_lain_lain'] ?? 0,
            };
            await db.insert('periods', newRow);
          }
          await db.execute('DROP TABLE periods_old');
        } else if (oldVersion < 3) {
          // v2 punya satu kolom "beban_listrik". v3 memisahkannya jadi
          // bulanan/per-2-minggu dan menambah beban_ipl. Nilai lama
          // dipindahkan ke "beban_listrik_bulanan" supaya data tidak hilang.
          await db.execute(
            'ALTER TABLE periods ADD COLUMN beban_listrik_bulanan REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE periods ADD COLUMN beban_listrik_dua_mingguan REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE periods ADD COLUMN beban_ipl REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE periods SET beban_listrik_bulanan = beban_listrik',
          );
        }
        if (oldVersion < 4) {
          // v4 menambah fitur Invoice: profil usaha (nama, alamat, rekening
          // bank, kontak person) disimpan satu baris supaya bisa dipakai
          // ulang di tiap invoice yang digenerate.
          await db.execute(_createBusinessProfileTableSql);
        }
        if (oldVersion < 5) {
          // v5: kategori Pendapatan diperluas dari 5 jadi 9 kolom (Cash,
          // QRIS Mandiri, EDC On Us/Off Us, GoFood, GrabFood, QRIS ESB,
          // Other, Pendapatan Bunga) dan Beban Operasional dapat 7 kolom
          // baru, mengikuti struktur laporan asli. Kolom lama
          // "penjualan_qris"/"penjualan_edc" (v1-v4) dipetakan ke kategori
          // yang paling dekat maknanya supaya data historis tidak hilang;
          // kolom lamanya sendiri dibiarkan ada di skema (tidak dipakai lagi
          // oleh Period.toMap/fromMap), sama seperti migrasi v3 dulu.
          // v1 sudah membuat kolom-kolom ini langsung di atas, jadi ALTER di
          // sini hanya berjalan untuk baris yang datang dari skema v2-v4
          // (yang belum punya kolom baru ini sama sekali).
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          Future<void> addCol(String name) async {
            if (cols.contains(name)) return;
            await db.execute('ALTER TABLE periods ADD COLUMN $name REAL NOT NULL DEFAULT 0');
          }

          await addCol('penjualan_cash');
          await addCol('penjualan_qris_mandiri');
          await addCol('penjualan_edc_on_us');
          await addCol('penjualan_edc_off_us');
          await addCol('penjualan_qris_esb');
          await addCol('penjualan_other');
          await addCol('pendapatan_bunga');
          await addCol('beban_mdr_gofood');
          await addCol('beban_mdr_grabfood');
          await addCol('beban_biaya_akomodasi');
          await addCol('beban_biaya_service_karyawan');
          await addCol('beban_penyusutan_bar');
          await addCol('beban_penyusutan_kitchen');
          await addCol('beban_penyusutan_furniture_area');

          if (cols.contains('penjualan_qris') && !cols.contains('penjualan_qris_mandiri')) {
            await db.execute('UPDATE periods SET penjualan_qris_mandiri = penjualan_qris');
          }
          if (cols.contains('penjualan_edc') && !cols.contains('penjualan_edc_on_us')) {
            await db.execute('UPDATE periods SET penjualan_edc_on_us = penjualan_edc');
          }

          await db.execute(_createInvoicesTableSql);
        }
        if (oldVersion < 6) {
          // v6: fitur "+ Tambah Akun" -- akun Pendapatan/Beban tambahan yang
          // ditambahkan bebas oleh pengguna sendiri (nama, nominal,
          // keterangan), disimpan sebagai JSON per periode supaya tidak
          // perlu migrasi skema tiap kali ada kategori baru.
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('custom_income_items')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN custom_income_items TEXT NOT NULL DEFAULT '[]'",
            );
          }
          if (!cols.contains('custom_expense_items')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN custom_expense_items TEXT NOT NULL DEFAULT '[]'",
            );
          }
        }
        if (oldVersion < 7) {
          // v7: modul Stock (Master Barang, Pembelian & Waste per barang,
          // Stock Opname) -- lihat lib/models/barang.dart &
          // lib/state/stock_editor.dart.
          await db.execute(_createBarangItemsTableSql);
          await db.execute(_createPembelianItemsTableSql);
          await db.execute(_createWasteItemsTableSql);
          await db.execute(_createStockOpnameTableSql);

          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('beban_waste_bahan_baku')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN beban_waste_bahan_baku REAL NOT NULL DEFAULT 0",
            );
          }
        }
        if (oldVersion < 8) {
          // v8: Fixed Asset Register -- daftar aset tetap global, penyusutan
          // dihitung otomatis dari sana (lihat lib/models/fixed_asset.dart &
          // lib/screens/tabs/aset_tab.dart), menggantikan input manual
          // "Penyusutan Bar/Kitchen/Furniture Area" yang sebelumnya diketik
          // langsung. Kategori "Office" ditambah supaya aset seperti Tablet
          // POS ikut punya tempat (sebelumnya cuma ada 3 kategori).
          await db.execute(_createFixedAssetsTableSql);

          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('beban_penyusutan_office')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN beban_penyusutan_office REAL NOT NULL DEFAULT 0",
            );
          }
        }
        if (oldVersion < 9) {
          // v9: Laporan Posisi Keuangan (Neraca) & Laporan Arus Kas -- lihat
          // lib/models/posisi_keuangan.dart & lib/models/arus_kas.dart. Akun
          // Kas/Bank, Piutang, Hutang, dan Modal/Prive diisi manual per
          // periode (saldo akhir, kecuali Modal Disetor/Prive yang diisi
          // sebagai nilai periode berjalan).
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          Future<void> addCol(String name, {String type = 'REAL', String defaultValue = '0'}) async {
            if (cols.contains(name)) return;
            await db.execute('ALTER TABLE periods ADD COLUMN $name $type NOT NULL DEFAULT $defaultValue');
          }

          await addCol('kas_bank_items', type: 'TEXT', defaultValue: "'[]'");
          await addCol('piutang_usaha');
          await addCol('beban_dibayar_dimuka');
          await addCol('hutang_usaha');
          await addCol('hutang_gaji_karyawan');
          await addCol('hutang_pb1');
          await addCol('hutang_pph21');
          await addCol('hutang_pph23');
          await addCol('hutang_pajak_badan');
          await addCol('hutang_service_charge');
          await addCol('hutang_lain_lain');
          await addCol('pinjaman');
          await addCol('custom_liability_items', type: 'TEXT', defaultValue: "'[]'");
          await addCol('modal_disetor_periode_ini');
          await addCol('prive_periode_ini');

          final profileCols = (await db.rawQuery('PRAGMA table_info(business_profile)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!profileCols.contains('modal_awal_usaha')) {
            await db.execute(
              "ALTER TABLE business_profile ADD COLUMN modal_awal_usaha REAL NOT NULL DEFAULT 0",
            );
          }
        }
        if (oldVersion < 10) {
          // v10: "Akun Tambahan Aset Lancar" -- akun ad-hoc (Piutang
          // Lain-lain, Uang Muka Supplier, Pajak Dibayar Dimuka, dst) di tab
          // Neraca, pola sama seperti custom_liability_items (v9).
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('custom_current_asset_items')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN custom_current_asset_items TEXT NOT NULL DEFAULT '[]'",
            );
          }
        }
        if (oldVersion < 11) {
          // v11: Alokasi Laba (persentase Reserve/Maintenance/Next Business
          // Fund + jumlah bulan Target Cash Reserve, sekali diisi di Profil
          // Usaha lalu dipakai di Ringkasan Tahunan) & Tax Control (tarif
          // PBJT/PB1 + PPh Final UMKM di Profil Usaha; realisasi bayar & dana
          // yang disisihkan per periode di tab Pajak).
          final profileCols = (await db.rawQuery('PRAGMA table_info(business_profile)'))
              .map((c) => c['name'] as String)
              .toSet();
          Future<void> addProfileCol(String name, String type, String defaultValue) async {
            if (profileCols.contains(name)) return;
            await db.execute(
              'ALTER TABLE business_profile ADD COLUMN $name $type NOT NULL DEFAULT $defaultValue',
            );
          }

          await addProfileCol('pct_reserve', 'REAL', '1');
          await addProfileCol('pct_maintenance', 'REAL', '1');
          await addProfileCol('pct_next_business_fund', 'REAL', '1.5');
          await addProfileCol('cash_reserve_bulan', 'INTEGER', '4');
          await addProfileCol('pbjt_tax_rate_persen', 'REAL', '10');
          await addProfileCol('pph_final_tax_rate_persen', 'REAL', '0.5');

          final periodCols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          Future<void> addPeriodCol(String name) async {
            if (periodCols.contains(name)) return;
            await db.execute('ALTER TABLE periods ADD COLUMN $name REAL NOT NULL DEFAULT 0');
          }

          await addPeriodCol('pbjt_tax_paid');
          await addPeriodCol('pbjt_tax_fund');
          await addPeriodCol('pph_final_tax_paid');
          await addPeriodCol('pph_final_tax_fund');
        }
        if (oldVersion < 12) {
          // v12: Jurnal Umum + Buku Besar (double-entry) -- modul baru
          // terpisah, berdampingan dengan tab-tab lama yang tetap berbasis
          // input manual per periode (lihat lib/models/journal.dart &
          // lib/services/journal_service.dart). 3 form transaksi sederhana
          // (Kas Masuk/Keluar/Transfer) auto-generate 1 journal_entries +
          // 2 journal_lines yang selalu seimbang debit=kredit.
          await db.execute(_createJournalEntriesTableSql);
          await db.execute(_createJournalLinesTableSql);
        }
        if (oldVersion < 13) {
          // v13: Rekonsiliasi Bank -- worksheet 2 kolom (Saldo Buku vs Saldo
          // Rekening Koran) susulan setelah Jurnal Penyesuaian, lihat
          // lib/models/bank_reconciliation.dart & lib/screens/
          // rekonsiliasi_bank_screen.dart.
          await db.execute(_createBankReconciliationsTableSql);
          await db.execute(_createBankReconciliationItemsTableSql);
        }
        if (oldVersion < 14) {
          // v14: "Pendapatan Diterima Dimuka" (unearned revenue, mis. DP
          // reservasi event yang belum terlaksana) -- field baru di tab
          // Neraca -> Liabilitas, otomatis dari saldo akun GL 20.103 (lihat
          // PeriodSyncService._withBalanceFields & catatan_relasi_kas_
          // periode.txt Bagian 5 & 13).
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('pendapatan_diterima_dimuka')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN pendapatan_diterima_dimuka REAL NOT NULL DEFAULT 0",
            );
          }
        }
        if (oldVersion < 15) {
          // v15: "SC Terkumpul" (Service Charge terkumpul periode ini) --
          // field baru di tab Penjualan, dipisah dari totalPenjualan supaya
          // Alokasi Laba (Reserve/Maintenance/R&D) bisa pakai basis Net Sales
          // yang mengecualikan SC, sesuai konfirmasi istri: SC = hak
          // karyawan (kewajiban 20.3), bukan bagian Alokasi Laba, sementara
          // totalPenjualan (termasuk SC) tetap dipakai apa adanya untuk basis
          // PBJT/PPh Final karena DPP pajak restoran memang mengikutkan SC.
          final cols = (await db.rawQuery('PRAGMA table_info(periods)'))
              .map((c) => c['name'] as String)
              .toSet();
          if (!cols.contains('sc_terkumpul')) {
            await db.execute(
              "ALTER TABLE periods ADD COLUMN sc_terkumpul REAL NOT NULL DEFAULT 0",
            );
          }
        }
      },
    );
  }

  Future<List<Period>> getAllPeriods() async {
    final db = await database;
    final rows = await db.query('periods', orderBy: 'start_date DESC, id DESC');
    return rows.map(Period.fromMap).toList();
  }

  Future<Period?> getPeriodById(int id) async {
    final db = await database;
    final rows = await db.query('periods', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Period.fromMap(rows.first);
  }

  /// Cari periode kalender (per bulan) yang sudah ada, untuk mencegah
  /// duplikat saat menambah periode baru.
  Future<Period?> getCalendarPeriod(int month, int year) async {
    final db = await database;
    final rows = await db.query(
      'periods',
      where: 'period_type = ? AND month = ? AND year = ?',
      whereArgs: ['calendar', month, year],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Period.fromMap(rows.first);
  }

  Future<Period> createCalendarPeriod(int month, int year) async {
    final db = await database;
    final period = Period.calendarMonth(month: month, year: year);
    final id = await db.insert('periods', period.toMap());
    return period.copyWith(id: id);
  }

  Future<Period> createCustomPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? customLabel,
  }) async {
    final db = await database;
    final period = Period.customRange(
      startDate: startDate,
      endDate: endDate,
      customLabel: customLabel,
    );
    final id = await db.insert('periods', period.toMap());
    return period.copyWith(id: id);
  }

  Future<void> updatePeriod(Period period) async {
    final db = await database;
    await db.update(
      'periods',
      period.toMap(),
      where: 'id = ?',
      whereArgs: [period.id],
    );
  }

  Future<void> deletePeriod(int id) async {
    final db = await database;
    // Tabel-tabel modul Stock tidak pakai FK constraint (konsisten dengan
    // gaya tabel lain di database ini), jadi baris terkait periode yang
    // dihapus perlu dibersihkan manual supaya tidak jadi sampah.
    await db.delete('pembelian_items', where: 'period_id = ?', whereArgs: [id]);
    await db.delete('waste_items', where: 'period_id = ?', whereArgs: [id]);
    await db.delete('stock_opname', where: 'period_id = ?', whereArgs: [id]);
    await db.delete('periods', where: 'id = ?', whereArgs: [id]);
  }

  // --- Modul Stock: Master Barang ---

  Future<List<BarangItem>> getAllBarangItems({bool onlyAktif = false}) async {
    final db = await database;
    final rows = await db.query(
      'barang_items',
      where: onlyAktif ? 'aktif = 1' : null,
      orderBy: 'kategori ASC, nama ASC',
    );
    return rows.map(BarangItem.fromMap).toList();
  }

  Future<BarangItem> insertBarangItem(BarangItem item) async {
    final db = await database;
    final id = await db.insert('barang_items', item.toMap());
    return BarangItem(
      id: id,
      kode: item.kode,
      nama: item.nama,
      kategori: item.kategori,
      satuan: item.satuan,
      hargaRataRata: item.hargaRataRata,
      aktif: item.aktif,
    );
  }

  Future<void> updateBarangItem(BarangItem item) async {
    final db = await database;
    await db.update('barang_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  /// Hitung ulang harga rata-rata tertimbang barang dari SELURUH histori
  /// pembelian tercatat (bukan cuma satu periode) -- lihat catatan desain
  /// di `lib/models/barang.dart`. Dipanggil tiap kali pembelian
  /// ditambah/diubah/dihapus. Kalau semua pembelian barang itu sudah
  /// dihapus (totalQty jadi 0), harga rata-rata LAMA sengaja dibiarkan
  /// (tidak direset ke 0) supaya stok yang masih ada tidak tiba-tiba
  /// bernilai Rp0.
  Future<void> _recalcHargaRataRata(Database db, int barangId) async {
    final rows = await db.rawQuery(
      'SELECT SUM(qty) as totalQty, SUM(qty * harga_satuan) as totalNilai '
      'FROM pembelian_items WHERE barang_id = ?',
      [barangId],
    );
    final totalQty = (rows.first['totalQty'] as num?)?.toDouble() ?? 0;
    final totalNilai = (rows.first['totalNilai'] as num?)?.toDouble() ?? 0;
    if (totalQty > 0) {
      await db.update(
        'barang_items',
        {'harga_rata_rata': totalNilai / totalQty},
        where: 'id = ?',
        whereArgs: [barangId],
      );
    }
  }

  // --- Modul Stock: Pembelian per Barang ---

  Future<List<PembelianItem>> getPembelianItemsByPeriod(int periodId) async {
    final db = await database;
    final rows = await db.query(
      'pembelian_items',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'tanggal ASC, id ASC',
    );
    return rows.map(PembelianItem.fromMap).toList();
  }

  Future<PembelianItem> insertPembelianItem(PembelianItem item) async {
    final db = await database;
    final id = await db.insert('pembelian_items', item.toMap());
    await _recalcHargaRataRata(db, item.barangId);
    return PembelianItem(
      id: id,
      periodId: item.periodId,
      barangId: item.barangId,
      tanggal: item.tanggal,
      qty: item.qty,
      hargaSatuan: item.hargaSatuan,
      keterangan: item.keterangan,
    );
  }

  Future<void> updatePembelianItem(PembelianItem item) async {
    final db = await database;
    await db.update('pembelian_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    await _recalcHargaRataRata(db, item.barangId);
  }

  Future<void> deletePembelianItem(int id, int barangId) async {
    final db = await database;
    await db.delete('pembelian_items', where: 'id = ?', whereArgs: [id]);
    await _recalcHargaRataRata(db, barangId);
  }

  // --- Modul Stock: Waste & Adjustment per Barang ---

  Future<List<WasteItem>> getWasteItemsByPeriod(int periodId) async {
    final db = await database;
    final rows = await db.query(
      'waste_items',
      where: 'period_id = ?',
      whereArgs: [periodId],
      orderBy: 'tanggal ASC, id ASC',
    );
    return rows.map(WasteItem.fromMap).toList();
  }

  Future<WasteItem> insertWasteItem(WasteItem item) async {
    final db = await database;
    final id = await db.insert('waste_items', item.toMap());
    return WasteItem(
      id: id,
      periodId: item.periodId,
      barangId: item.barangId,
      tanggal: item.tanggal,
      qty: item.qty,
      alasan: item.alasan,
      nilaiRupiah: item.nilaiRupiah,
      keterangan: item.keterangan,
    );
  }

  Future<void> updateWasteItem(WasteItem item) async {
    final db = await database;
    await db.update('waste_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteWasteItem(int id) async {
    final db = await database;
    await db.delete('waste_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- Modul Stock: Stock Opname ---

  Future<List<StockOpnameRow>> getStockOpnameByPeriod(int periodId) async {
    final db = await database;
    final rows = await db.query('stock_opname', where: 'period_id = ?', whereArgs: [periodId]);
    return rows.map(StockOpnameRow.fromMap).toList();
  }

  /// Stok fisik terakhir barang [barangId] dari periode TERDEKAT sebelum
  /// [periodId] (diurutkan dari start_date, bukan id) yang sudah punya
  /// baris Stock Opname -- dipakai sebagai default Stok Awal periode
  /// berjalan kalau belum diisi manual.
  Future<double> getPreviousStokFisik(int periodId, int barangId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT so.stok_fisik as stokFisik FROM stock_opname so
      JOIN periods p ON p.id = so.period_id
      WHERE so.barang_id = ? AND p.start_date < (SELECT start_date FROM periods WHERE id = ?)
      ORDER BY p.start_date DESC LIMIT 1
    ''', [barangId, periodId]);
    if (rows.isEmpty) return 0;
    return (rows.first['stokFisik'] as num?)?.toDouble() ?? 0;
  }

  /// Insert baris baru kalau [row.id] null & belum ada baris untuk
  /// (period_id, barang_id) itu, atau update baris yang sudah ada.
  Future<StockOpnameRow> upsertStockOpname(StockOpnameRow row) async {
    final db = await database;
    var id = row.id;
    if (id == null) {
      final existing = await db.query(
        'stock_opname',
        where: 'period_id = ? AND barang_id = ?',
        whereArgs: [row.periodId, row.barangId],
        limit: 1,
      );
      if (existing.isNotEmpty) id = existing.first['id'] as int;
    }
    final withId = StockOpnameRow(
      id: id,
      periodId: row.periodId,
      barangId: row.barangId,
      stokAwal: row.stokAwal,
      stokFisik: row.stokFisik,
    );
    if (id != null) {
      await db.update('stock_opname', withId.toMap(), where: 'id = ?', whereArgs: [id]);
      return withId;
    }
    final newId = await db.insert('stock_opname', withId.toMap());
    return StockOpnameRow(
      id: newId,
      periodId: row.periodId,
      barangId: row.barangId,
      stokAwal: row.stokAwal,
      stokFisik: row.stokFisik,
    );
  }

  // --- Fixed Asset Register ---

  Future<List<FixedAssetItem>> getAllFixedAssets({bool onlyAktif = false}) async {
    final db = await database;
    final rows = await db.query(
      'fixed_assets',
      where: onlyAktif ? 'aktif = 1' : null,
      orderBy: 'kategori ASC, nama ASC',
    );
    return rows.map(FixedAssetItem.fromMap).toList();
  }

  Future<FixedAssetItem> insertFixedAsset(FixedAssetItem item) async {
    final db = await database;
    final id = await db.insert('fixed_assets', item.toMap());
    return FixedAssetItem(
      id: id,
      kode: item.kode,
      nama: item.nama,
      kategori: item.kategori,
      lokasi: item.lokasi,
      tanggalBeli: item.tanggalBeli,
      hargaPerolehan: item.hargaPerolehan,
      umurTahun: item.umurTahun,
      aktif: item.aktif,
      alasanNonaktif: item.alasanNonaktif,
      tanggalNonaktif: item.tanggalNonaktif,
    );
  }

  Future<void> updateFixedAsset(FixedAssetItem item) async {
    final db = await database;
    await db.update('fixed_assets', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  /// Ambil profil usaha (selalu baris id=1). Kalau belum pernah diisi,
  /// kembalikan [BusinessProfile] kosong dengan nilai default.
  Future<BusinessProfile> getBusinessProfile() async {
    final db = await database;
    final rows = await db.query('business_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return const BusinessProfile();
    return BusinessProfile.fromMap(rows.first);
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    final db = await database;
    await db.insert(
      'business_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Riwayat Invoice ---

  Future<List<InvoiceRecord>> getAllInvoices() async {
    final db = await database;
    final rows = await db.query('invoices', orderBy: 'created_at DESC, id DESC');
    return rows.map(InvoiceRecord.fromMap).toList();
  }

  Future<InvoiceRecord?> getInvoiceById(int id) async {
    final db = await database;
    final rows = await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InvoiceRecord.fromMap(rows.first);
  }

  Future<InvoiceRecord> insertInvoice(InvoiceRecord invoice) async {
    final db = await database;
    final id = await db.insert('invoices', invoice.toMap());
    return invoice.copyWith(id: id);
  }

  Future<void> updateInvoice(InvoiceRecord invoice) async {
    final db = await database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteInvoice(int id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  // --- Jurnal Umum + Buku Besar (double-entry) ---

  /// Simpan 1 [JournalEntry] beserta baris-baris [JournalLine]-nya
  /// (biasanya 2, seimbang debit=kredit) dalam satu transaksi supaya tidak
  /// pernah ada entry "yatim" tanpa baris kalau proses gagal di tengah.
  Future<JournalEntry> postJournalEntry(JournalEntry entry, List<JournalLine> lines) async {
    final db = await database;
    late int entryId;
    await db.transaction((txn) async {
      entryId = await txn.insert('journal_entries', entry.toMap());
      for (final line in lines) {
        await txn.insert('journal_lines', line.copyWithEntryId(entryId).toMap());
      }
    });
    return JournalEntry(
      id: entryId,
      tanggal: entry.tanggal,
      keterangan: entry.keterangan,
      sumber: entry.sumber,
      pihak: entry.pihak,
      createdAt: entry.createdAt,
    );
  }

  Future<List<JournalEntry>> getAllJournalEntries() async {
    final db = await database;
    final rows = await db.query('journal_entries', orderBy: 'tanggal DESC, id DESC');
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<JournalEntry?> getJournalEntryById(int id) async {
    final db = await database;
    final rows = await db.query('journal_entries', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<List<JournalLine>> getJournalLinesForEntry(int journalEntryId) async {
    final db = await database;
    final rows = await db.query(
      'journal_lines',
      where: 'journal_entry_id = ?',
      whereArgs: [journalEntryId],
    );
    return rows.map(JournalLine.fromMap).toList();
  }

  /// Semua baris jurnal untuk satu akun tertentu, digabung dengan info
  /// entry induknya (tanggal, keterangan, sumber, pihak) -- dipakai untuk
  /// kartu Buku Besar per akun.
  Future<List<Map<String, Object?>>> getJournalLinesForAccount(String akunKode) async {
    final db = await database;
    return db.rawQuery('''
      SELECT je.id as journal_entry_id, je.tanggal as tanggal, je.keterangan as keterangan,
             je.sumber as sumber, je.pihak as pihak, jl.debit as debit, jl.kredit as kredit
      FROM journal_lines jl
      JOIN journal_entries je ON je.id = jl.journal_entry_id
      WHERE jl.akun_kode = ?
      ORDER BY je.tanggal ASC, je.id ASC
    ''', [akunKode]);
  }

  /// Total debit & kredit per akun dari SELURUH journal_lines -- dasar
  /// Neraca Saldo (GL). Hanya akun yang punya minimal 1 baris transaksi yang
  /// dikembalikan.
  Future<List<Map<String, Object?>>> getTrialBalanceRaw() async {
    final db = await database;
    return db.rawQuery('''
      SELECT akun_kode, SUM(debit) as total_debit, SUM(kredit) as total_kredit
      FROM journal_lines
      GROUP BY akun_kode
    ''');
  }

  Future<void> deleteJournalEntry(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('journal_lines', where: 'journal_entry_id = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- Rekonsiliasi Bank ---

  Future<List<BankReconciliation>> getAllBankReconciliations() async {
    final db = await database;
    final rows = await db.query('bank_reconciliations', orderBy: 'tanggal_cutoff DESC, id DESC');
    return rows.map(BankReconciliation.fromMap).toList();
  }

  Future<BankReconciliation> insertBankReconciliation(BankReconciliation r) async {
    final db = await database;
    final id = await db.insert('bank_reconciliations', r.toMap());
    return BankReconciliation(
      id: id,
      akunKode: r.akunKode,
      tanggalCutoff: r.tanggalCutoff,
      saldoRekeningKoran: r.saldoRekeningKoran,
      catatan: r.catatan,
      createdAt: r.createdAt,
    );
  }

  Future<void> updateBankReconciliation(BankReconciliation r) async {
    final db = await database;
    await db.update('bank_reconciliations', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteBankReconciliation(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('bank_reconciliation_items', where: 'reconciliation_id = ?', whereArgs: [id]);
      await txn.delete('bank_reconciliations', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<BankReconciliationItem>> getBankReconciliationItems(int reconciliationId) async {
    final db = await database;
    final rows = await db.query(
      'bank_reconciliation_items',
      where: 'reconciliation_id = ?',
      whereArgs: [reconciliationId],
    );
    return rows.map(BankReconciliationItem.fromMap).toList();
  }

  Future<BankReconciliationItem> insertBankReconciliationItem(BankReconciliationItem item) async {
    final db = await database;
    final id = await db.insert('bank_reconciliation_items', item.toMap());
    return BankReconciliationItem(
      id: id,
      reconciliationId: item.reconciliationId,
      tipe: item.tipe,
      keterangan: item.keterangan,
      jumlah: item.jumlah,
      posted: item.posted,
      journalEntryId: item.journalEntryId,
    );
  }

  Future<void> updateBankReconciliationItem(BankReconciliationItem item) async {
    final db = await database;
    await db.update(
      'bank_reconciliation_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteBankReconciliationItem(int id) async {
    final db = await database;
    await db.delete('bank_reconciliation_items', where: 'id = ?', whereArgs: [id]);
  }
}
