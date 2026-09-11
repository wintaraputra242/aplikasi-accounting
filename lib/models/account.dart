/// Chart of Accounts (COA) untuk modul Jurnal Umum + Buku Besar (lihat
/// lib/services/journal_service.dart & lib/models/journal.dart). Konvensi
/// nomor akun final dari revisi Mangana (blueprint_revisi_mangana.txt Bagian
/// 2). Modul ini berdiri sendiri di samping tab-tab lama berbasis input
/// manual per periode -- tidak menggantikannya.
library;

enum AccountType { aset, liabilitas, ekuitas, pendapatan, hpp, beban }

class Account {
  final String kode;
  final String nama;
  final AccountType tipe;
  /// Sub-kelompok untuk tampilan (mis. "Kas & Bank", "Piutang") -- tidak
  /// dipakai untuk logika, murni pengelompokan di UI.
  final String kategori;

  const Account({
    required this.kode,
    required this.nama,
    required this.tipe,
    this.kategori = '',
  });

  /// Aset/HPP/Beban bersaldo normal Debit; Liabilitas/Ekuitas/Pendapatan
  /// bersaldo normal Kredit. Dipakai untuk menghitung saldo berjalan di Buku
  /// Besar & tanda saldo di Neraca Saldo (GL).
  bool get isDebitNormal =>
      tipe == AccountType.aset || tipe == AccountType.hpp || tipe == AccountType.beban;

  String get label => '$kode - $nama';
}

const kChartOfAccounts = <Account>[
  // --- ASET ---
  Account(kode: '10.1', nama: 'Kas', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.2', nama: 'Bank BCA', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.3', nama: 'Bank BRI', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.9', nama: 'Bank BCA (Rekening Lain)', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.10', nama: 'Bank Mandiri', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.12', nama: 'QRIS Clearing', tipe: AccountType.aset, kategori: 'Kas & Bank'),
  Account(kode: '10.6', nama: 'Piutang Pegawai', tipe: AccountType.aset, kategori: 'Piutang'),
  Account(kode: '10.7', nama: 'Piutang Konsinyasi', tipe: AccountType.aset, kategori: 'Piutang'),
  Account(kode: '10.8', nama: 'Piutang Kartu Kredit', tipe: AccountType.aset, kategori: 'Piutang'),
  Account(kode: '10.11', nama: 'Piutang Usaha', tipe: AccountType.aset, kategori: 'Piutang'),
  Account(kode: '13.2', nama: 'Persediaan Bahan Baku', tipe: AccountType.aset, kategori: 'Persediaan'),
  Account(kode: '13.3', nama: 'Persediaan Packaging', tipe: AccountType.aset, kategori: 'Persediaan'),
  Account(kode: '13.4', nama: 'Perlengkapan', tipe: AccountType.aset, kategori: 'Persediaan'),
  Account(
    kode: '13.5',
    nama: 'Sewa Dibayar Dimuka',
    tipe: AccountType.aset,
    kategori: 'Aset Lancar Lainnya',
  ),
  // Aset Tetap & Akumulasi Penyusutan mengikuti 4 kategori yang sama persis
  // dengan Fixed Asset Register (kKategoriAset di lib/models/fixed_asset.dart:
  // Bar/Kitchen/Furniture Area/Office) -- BUKAN Tanah/Bangunan/Peralatan --
  // supaya posting Jurnal Penyesuaian Depresiasi (lihat
  // lib/services/journal_service.dart: postDepresiasiPeriode &
  // kAkumulasiPenyusutanKode/kBebanDepresiasiKode di bawah) bisa langsung
  // ditelusuri balik ke daftar aset per kategori itu. Blueprint revisi
  // Mangana sengaja skip kategori Tanah/Bangunan/Renovasi terpisah.
  Account(kode: '11.1', nama: 'Aset Tetap Bar', tipe: AccountType.aset, kategori: 'Aset Tetap'),
  Account(kode: '11.2', nama: 'Aset Tetap Kitchen', tipe: AccountType.aset, kategori: 'Aset Tetap'),
  Account(
    kode: '11.3',
    nama: 'Aset Tetap Furniture Area',
    tipe: AccountType.aset,
    kategori: 'Aset Tetap',
  ),
  Account(kode: '11.4', nama: 'Aset Tetap Office', tipe: AccountType.aset, kategori: 'Aset Tetap'),
  Account(
    kode: '12.1',
    nama: 'Akumulasi Penyusutan Bar',
    tipe: AccountType.aset,
    kategori: 'Aset Tetap',
  ),
  Account(
    kode: '12.2',
    nama: 'Akumulasi Penyusutan Kitchen',
    tipe: AccountType.aset,
    kategori: 'Aset Tetap',
  ),
  Account(
    kode: '12.3',
    nama: 'Akumulasi Penyusutan Furniture Area',
    tipe: AccountType.aset,
    kategori: 'Aset Tetap',
  ),
  Account(
    kode: '12.4',
    nama: 'Akumulasi Penyusutan Office',
    tipe: AccountType.aset,
    kategori: 'Aset Tetap',
  ),

  // --- LIABILITAS ---
  Account(kode: '20.1', nama: 'Hutang Dagang', tipe: AccountType.liabilitas, kategori: 'Hutang Usaha'),
  Account(kode: '20.100', nama: 'Hutang Usaha', tipe: AccountType.liabilitas, kategori: 'Hutang Usaha'),
  Account(kode: '20.101', nama: 'Hutang Gaji', tipe: AccountType.liabilitas, kategori: 'Hutang Usaha'),
  // 20.102 "Hutang Pajak" (generik) sengaja dihapus -- sudah ada akun pajak
  // spesifik per jenis (PBJT/PB1, PPh21, PPh Final UMKM, PPN), istri
  // konfirmasi akun generik ini redundant (catatan_relasi_kas_periode.txt
  // Bagian 4 Q10).
  Account(
    kode: '20.103',
    nama: 'Pendapatan Diterima Dimuka',
    tipe: AccountType.liabilitas,
    kategori: 'Hutang Usaha',
  ),
  Account(kode: '20.104', nama: 'Hutang PBJT/PB1', tipe: AccountType.liabilitas, kategori: 'Hutang Pajak'),
  // 20.105 Hutang PPh Final UMKM -- istri konfirmasi TIDAK ADA saldo (akun
  // lama era skema UMKM, bukan akun aktif untuk PPh Final terutang saat
  // ini). Dipertahankan di COA untuk historical record, sengaja TIDAK
  // dibuatkan field Neraca otomatis / tidak disalurkan ke
  // period_sync_service.dart (catatan_relasi_kas_periode_tadi_pagi.txt
  // Bagian 4 no.11, dijawab di sesi 2026-09-10).
  Account(
    kode: '20.105',
    nama: 'Hutang PPh Final UMKM',
    tipe: AccountType.liabilitas,
    kategori: 'Hutang Pajak',
  ),
  // 20.106 Hutang PPh 23 -- istri konfirmasi Mangana pakai jasa yang
  // berpotensi kena PPh 23 (konsultan/marketing/maintenance/sewa alat/dst)
  // dan mau dicatat pakai akun khusus ini, bukan "Hutang Pajak" generik
  // (catatan_relasi_kas_periode_tadi_pagi.txt Bagian 2 no.1, dijawab
  // di sesi 2026-09-10).
  Account(kode: '20.106', nama: 'Hutang PPh 23', tipe: AccountType.liabilitas, kategori: 'Hutang Pajak'),
  Account(kode: '20.2', nama: 'Hutang PPh21', tipe: AccountType.liabilitas, kategori: 'Hutang Pajak'),
  Account(kode: '20.3', nama: 'Titipan Karyawan', tipe: AccountType.liabilitas, kategori: 'Titipan'),
  // 20.4 Titipan Konsinyasi -- fungsinya redundant dengan 20.7 Hutang
  // Konsinyasi (keduanya = kewajiban ke pemilik barang konsinyasi yang
  // belum disetor). Mangana TIDAK punya bisnis konsinyasi saat ini, jadi
  // keduanya tidak pernah kepakai. Dipertahankan di COA (tidak dihapus)
  // untuk future-proofing kalau nanti Mangana mulai terima barang
  // konsinyasi -- tapi sengaja TIDAK dibuatkan field Neraca/automation
  // (catatan_relasi_kas_periode_tadi_pagi.txt Bagian 4 no.9/15, dijawab
  // di sesi 2026-09-10).
  Account(kode: '20.4', nama: 'Titipan Konsinyasi', tipe: AccountType.liabilitas, kategori: 'Titipan'),
  Account(kode: '20.5', nama: 'Titipan Lain-lain', tipe: AccountType.liabilitas, kategori: 'Titipan'),
  // 20.6 Hutang PPN -- Mangana BELUM PKP, masih proses pengajuan,
  // perkiraan mulai berstatus PKP awal 2027 (tergantung persetujuan).
  // Dipertahankan di COA, tapi sengaja belum dibuatkan field Neraca/
  // automation sampai resmi PKP dan mulai ada transaksi PPN nyata
  // (catatan_relasi_kas_periode_tadi_pagi.txt Bagian 4 no.14/11, dijawab
  // di sesi 2026-09-10).
  Account(kode: '20.6', nama: 'Hutang PPN', tipe: AccountType.liabilitas, kategori: 'Hutang Pajak'),
  // 20.7 Hutang Konsinyasi -- lihat catatan di 20.4 Titipan Konsinyasi
  // (redundant, keduanya belum pernah kepakai karena Mangana belum ada
  // bisnis konsinyasi).
  Account(kode: '20.7', nama: 'Hutang Konsinyasi', tipe: AccountType.liabilitas, kategori: 'Hutang Usaha'),
  Account(
    kode: '21.1',
    nama: 'Hutang Bank Jangka Pendek',
    tipe: AccountType.liabilitas,
    kategori: 'Hutang Bank',
  ),
  Account(
    kode: '21.2',
    nama: 'Hutang Bank Jangka Panjang',
    tipe: AccountType.liabilitas,
    kategori: 'Hutang Bank',
  ),

  // --- EKUITAS ---
  Account(kode: '30.1', nama: 'Modal Pemilik', tipe: AccountType.ekuitas, kategori: 'Ekuitas'),
  Account(kode: '31.1', nama: 'Laba Ditahan', tipe: AccountType.ekuitas, kategori: 'Ekuitas'),
  Account(kode: '32.1', nama: 'Prive', tipe: AccountType.ekuitas, kategori: 'Ekuitas'),
  Account(kode: '33.1', nama: 'Laba Berjalan', tipe: AccountType.ekuitas, kategori: 'Ekuitas'),

  // --- REVENUE ---
  Account(kode: '40.1', nama: 'Penjualan Food', tipe: AccountType.pendapatan, kategori: 'Penjualan'),
  Account(kode: '40.2', nama: 'Penjualan Beverage', tipe: AccountType.pendapatan, kategori: 'Penjualan'),
  Account(kode: '40.3', nama: 'Penjualan Lain-lain', tipe: AccountType.pendapatan, kategori: 'Penjualan'),
  Account(kode: '40.4', nama: 'Pendapatan Bunga', tipe: AccountType.pendapatan, kategori: 'Penjualan'),

  // --- COGS/HPP ---
  Account(kode: '50.1', nama: 'HPP Food', tipe: AccountType.hpp, kategori: 'HPP'),
  Account(kode: '50.2', nama: 'HPP Beverage', tipe: AccountType.hpp, kategori: 'HPP'),
  Account(kode: '50.6', nama: 'HPP Shrinkage/Waste', tipe: AccountType.hpp, kategori: 'HPP'),

  // --- OPERATING EXPENSE ---
  Account(kode: '61.1', nama: 'Beban Gaji Karyawan', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.2', nama: 'Beban Listrik', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(
    kode: '61.3',
    nama: 'Beban Supplies & Cleaning',
    tipe: AccountType.beban,
    kategori: 'Beban Operasional',
  ),
  Account(kode: '61.4', nama: 'Beban MDR QRIS', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.5', nama: 'Beban MDR EDC', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.6', nama: 'Beban MDR ESB', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.7', nama: 'Beban MDR Go-Food', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.8', nama: 'Beban MDR Grab-Food', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.9', nama: 'Beban Marketing', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(
    kode: '61.10',
    nama: 'Beban Adm Transfer',
    tipe: AccountType.beban,
    kategori: 'Beban Operasional',
  ),
  Account(kode: '61.11', nama: 'Beban Kartu Debit', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(
    kode: '61.12',
    nama: 'Beban Admin Rekening',
    tipe: AccountType.beban,
    kategori: 'Beban Operasional',
  ),
  Account(kode: '61.13', nama: 'Pajak Rekening', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(kode: '61.14', nama: 'Beban Akomodasi', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(
    kode: '61.15',
    nama: 'Beban Service Karyawan',
    tipe: AccountType.beban,
    kategori: 'Beban Operasional',
  ),
  Account(kode: '61.16', nama: 'Beban Sewa', tipe: AccountType.beban, kategori: 'Beban Operasional'),
  Account(
    kode: '61.17',
    nama: 'Beban Depresiasi Bar',
    tipe: AccountType.beban,
    kategori: 'Beban Penyusutan',
  ),
  Account(
    kode: '61.18',
    nama: 'Beban Depresiasi Kitchen',
    tipe: AccountType.beban,
    kategori: 'Beban Penyusutan',
  ),
  Account(
    kode: '61.19',
    nama: 'Beban Depresiasi Furniture Area',
    tipe: AccountType.beban,
    kategori: 'Beban Penyusutan',
  ),
  Account(
    kode: '61.20',
    nama: 'Beban Depresiasi Office',
    tipe: AccountType.beban,
    kategori: 'Beban Penyusutan',
  ),
  Account(kode: '61.21', nama: 'Beban Lain-lain', tipe: AccountType.beban, kategori: 'Beban Operasional'),
];

Account? findAccount(String kode) {
  for (final a in kChartOfAccounts) {
    if (a.kode == kode) return a;
  }
  return null;
}

/// Akun kas/bank yang boleh dipilih sebagai sisi Kas/Bank di form Kas
/// Masuk/Keluar/Transfer -- semua akun berkategori "Kas & Bank" termasuk
/// QRIS Clearing (dipakai sebagai akun transit, lihat catatan QRIS di
/// blueprint).
final kAkunKasBank = kChartOfAccounts.where((a) => a.kategori == 'Kas & Bank').toList();

/// Akun bank riil yang punya rekening koran fisik -- dipakai untuk pilihan
/// akun di layar Rekonsiliasi Bank. TIDAK termasuk Kas (uang tunai, tidak
/// ada rekening koran) atau QRIS Clearing (akun transit internal, bukan
/// rekening bank sungguhan -- lihat catatan QRIS di blueprint).
final kAkunBankRekening =
    kAkunKasBank.where((a) => a.kode != '10.1' && a.kode != '10.12').toList();

/// Kode akun Beban Depresiasi per kategori Fixed Asset Register (kKategoriAset)
/// -- dipakai oleh [JournalService.postDepresiasiPeriode] untuk posting
/// Jurnal Penyesuaian Depresiasi otomatis.
const kBebanDepresiasiKode = {
  'Bar': '61.17',
  'Kitchen': '61.18',
  'Furniture Area': '61.19',
  'Office': '61.20',
};

/// Kode akun Akumulasi Penyusutan per kategori Fixed Asset Register,
/// pasangan dari [kBebanDepresiasiKode].
const kAkumulasiPenyusutanKode = {
  'Bar': '12.1',
  'Kitchen': '12.2',
  'Furniture Area': '12.3',
  'Office': '12.4',
};
