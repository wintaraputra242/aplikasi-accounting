import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../utils/formatters.dart';

/// Sembilan kategori penjualan yang didukung aplikasi.
const kKategoriPenjualan = [
  'cash',
  'qris_mandiri',
  'edc_on_us',
  'edc_off_us',
  'gofood',
  'grabfood',
  'qris_esb',
  'other',
  'bunga',
];

/// Hasil olah upload Excel penjualan: total per kategori, plus baris yang
/// kategorinya tidak dikenali (agar tidak ada nominal yang hilang diam-diam).
class PenjualanParseResult {
  final Map<String, double> totals; // key: salah satu dari kKategoriPenjualan
  final Map<String, double> tidakDikenali; // label asli -> total nominal
  final int barisDiproses;

  const PenjualanParseResult({
    required this.totals,
    required this.tidakDikenali,
    required this.barisDiproses,
  });

  double get totalTidakDikenali =>
      tidakDikenali.values.fold(0, (a, b) => a + b);
}

class PembelianParseResult {
  final double total;
  final int barisDiproses;

  const PembelianParseResult({required this.total, required this.barisDiproses});
}

String _cellToString(Data? cell) {
  final v = cell?.value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.toString();
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return v.value.toString();
  if (v is BoolCellValue) return v.value.toString();
  return v.toString();
}

double _cellToNumber(Data? cell) {
  final v = cell?.value;
  if (v == null) return 0;
  if (v is IntCellValue) return v.value.toDouble();
  if (v is DoubleCellValue) return v.value;
  return parseFlexibleNumber(v.toString());
}

/// Semua sheet non-kosong dalam file Excel, dalam urutan aslinya. Template
/// yang kita buat sendiri menyertakan sheet "Petunjuk" tambahan, jadi parser
/// tidak boleh berasumsi data selalu ada di sheet pertama.
List<List<List<Data?>>> _allSheetsRows(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    throw const FormatException('File Excel tidak memiliki sheet.');
  }
  final sheets = excel.tables.values.map((t) => t.rows).where((r) => r.isNotEmpty).toList();
  if (sheets.isEmpty) {
    throw const FormatException('File Excel kosong.');
  }
  return sheets;
}

const _kategoriHeaderKeywords = [
  'kategori', 'category', 'jenis', 'metode', 'pembayaran', 'channel',
];
const _nominalHeaderKeywords = [
  'nominal', 'total', 'jumlah', 'amount', 'omzet', 'omset', 'pendapatan', 'penjualan',
];

({int row, int catCol, int nomCol})? _findPenjualanHeader(List<List<Data?>> rows) {
  for (var r = 0; r < rows.length && r < 15; r++) {
    final row = rows[r];
    int? catCol;
    int? nomCol;
    for (var c = 0; c < row.length; c++) {
      final text = _cellToString(row[c]).toLowerCase();
      if (text.isEmpty) continue;
      catCol ??= _kategoriHeaderKeywords.any(text.contains) ? c : null;
      nomCol ??= _nominalHeaderKeywords.any(text.contains) ? c : null;
    }
    if (catCol != null && nomCol != null) {
      return (row: r, catCol: catCol, nomCol: nomCol);
    }
  }
  return null;
}

({int row, int col})? _findSingleColumn(List<List<Data?>> rows, List<String> keywords) {
  for (var r = 0; r < rows.length && r < 15; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final text = _cellToString(row[c]).toLowerCase();
      if (text.isNotEmpty && keywords.any(text.contains)) {
        return (row: r, col: c);
      }
    }
  }
  return null;
}

/// Cocokkan teks kategori mentah dari Excel ke salah satu dari 9 kategori
/// baku (lihat [kKategoriPenjualan]). Return null jika tidak dikenali.
///
/// Urutan pengecekan sengaja dari yang paling spesifik ke paling umum, mis.
/// "Income Qris ESB" harus kena kategori `qris_esb`, bukan `qris_mandiri`,
/// jadi kata kunci "esb" dicek lebih dulu daripada "qris" generik. EDC tanpa
/// keterangan "on us"/"off us" sengaja TIDAK ditebak (return null) supaya
/// nominalnya tidak salah masuk kategori -- munculnya sebagai "tidak
/// dikenali" dan bisa ditambahkan manual oleh pengguna.
String? matchKategoriPenjualan(String rawLabel) {
  final t = rawLabel.toLowerCase().trim();

  if (t.contains('bunga')) return 'bunga';
  if (t.contains('esb')) return 'qris_esb';
  if (t.contains('on us') || t.contains('on-us') || t.contains('onus')) return 'edc_on_us';
  if (t.contains('off us') || t.contains('off-us') || t.contains('offus')) return 'edc_off_us';
  if (t.contains('grab')) return 'grabfood';
  if (t.contains('gofood') || t.contains('go food') || t.contains('gojek')) return 'gofood';
  if (t.contains('qris') || RegExp(r'\bqr\b').hasMatch(t)) return 'qris_mandiri';
  if (t.contains('cash') || t.contains('tunai')) return 'cash';
  if (t.contains('other') || t.contains('lain')) return 'other';
  return null;
}

PenjualanParseResult _parsePenjualanRows(
  List<List<Data?>> rows, {
  required int catCol,
  required int nomCol,
  required int startRow,
}) {
  final totals = {for (final k in kKategoriPenjualan) k: 0.0};
  final tidakDikenali = <String, double>{};
  var diproses = 0;

  for (var r = startRow; r < rows.length; r++) {
    final row = rows[r];
    if (catCol >= row.length) continue;
    final rawKategori = _cellToString(row[catCol]).trim();
    if (rawKategori.isEmpty) continue;
    final nominal = nomCol < row.length ? _cellToNumber(row[nomCol]) : 0.0;
    if (nominal == 0) continue;

    final matched = matchKategoriPenjualan(rawKategori);
    if (matched != null) {
      totals[matched] = totals[matched]! + nominal;
    } else {
      tidakDikenali[rawKategori] = (tidakDikenali[rawKategori] ?? 0) + nominal;
    }
    diproses++;
  }

  return PenjualanParseResult(totals: totals, tidakDikenali: tidakDikenali, barisDiproses: diproses);
}

/// Parse file Excel penjualan: setiap baris berisi kategori pembayaran &
/// nominal transaksi. Dijumlahkan per kategori (qris/cash/edc/grabfood/gofood).
///
/// Mencoba tiap sheet dalam file (template kita sendiri punya sheet
/// "Petunjuk" tambahan) dan memakai sheet pertama yang kolom Kategori &
/// Nominal-nya berhasil terdeteksi lewat header.
PenjualanParseResult parsePenjualanExcel(Uint8List bytes) {
  final sheets = _allSheetsRows(bytes);

  for (final rows in sheets) {
    final header = _findPenjualanHeader(rows);
    if (header == null) continue;
    final result = _parsePenjualanRows(
      rows,
      catCol: header.catCol,
      nomCol: header.nomCol,
      startRow: header.row + 1,
    );
    if (result.barisDiproses > 0) return result;
  }

  // Fallback: tidak ada header yang cocok di sheet manapun, coba kolom A/B
  // pada sheet pertama tanpa header.
  final fallback = _parsePenjualanRows(sheets.first, catCol: 0, nomCol: 1, startRow: 0);
  if (fallback.barisDiproses == 0) {
    throw const FormatException(
      'Tidak ada baris data yang bisa dibaca. Pastikan file memiliki kolom '
      'Kategori dan Nominal.',
    );
  }
  return fallback;
}

const _pembelianNominalKeywords = [
  'total', 'nominal', 'jumlah', 'harga', 'subtotal', 'amount',
];

PembelianParseResult _parsePembelianRows(
  List<List<Data?>> rows, {
  required int nomCol,
  required int startRow,
}) {
  double total = 0;
  var diproses = 0;

  for (var r = startRow; r < rows.length; r++) {
    final row = rows[r];
    if (nomCol >= row.length) continue;
    final nominal = _cellToNumber(row[nomCol]);
    if (nominal == 0) continue;
    total += nominal;
    diproses++;
  }

  return PembelianParseResult(total: total, barisDiproses: diproses);
}

/// Parse file Excel pembelian bahan baku: menjumlahkan seluruh nominal pada
/// kolom total/nominal/jumlah untuk mendapatkan total pembelian bahan baku.
///
/// Mencoba tiap sheet dalam file dan memakai sheet pertama yang kolom
/// Nominal-nya berhasil terdeteksi lewat header.
PembelianParseResult parsePembelianExcel(Uint8List bytes) {
  final sheets = _allSheetsRows(bytes);

  for (final rows in sheets) {
    final match = _findSingleColumn(rows, _pembelianNominalKeywords);
    if (match == null) continue;
    final result = _parsePembelianRows(rows, nomCol: match.col, startRow: match.row + 1);
    if (result.barisDiproses > 0) return result;
  }

  final fallback = _parsePembelianRows(sheets.first, nomCol: 1, startRow: 0);
  if (fallback.barisDiproses == 0) {
    throw const FormatException(
      'Tidak ada baris data yang bisa dibaca. Pastikan file memiliki kolom '
      'Total/Nominal/Jumlah pembelian.',
    );
  }
  return fallback;
}
