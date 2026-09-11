import 'package:intl/intl.dart';

final _rupiahFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Format angka menjadi "Rp 1.234.567".
String formatRupiah(double value) => _rupiahFormat.format(value);

/// Format angka menjadi persen 1 desimal, mis. "12,3%".
String formatPercent(double value) => '${value.toStringAsFixed(1).replaceAll('.', ',')}%';

/// Parse teks bebas (mis. dari [TextField] atau cell Excel) menjadi [double].
/// Menangani format "Rp 1.000.000", "1.000.000,50", "1,000,000.50", dsb.
double parseFlexibleNumber(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return 0;

  // Buang semua karakter selain digit, koma, titik, dan minus.
  text = text.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (text.isEmpty) return 0;

  final hasComma = text.contains(',');
  final hasDot = text.contains('.');

  if (hasComma && hasDot) {
    // Pemisah ribuan adalah karakter yang muncul lebih dulu.
    if (text.indexOf(',') < text.indexOf('.')) {
      // 1,000,000.50 -> koma ribuan, titik desimal
      text = text.replaceAll(',', '');
    } else {
      // 1.000.000,50 -> titik ribuan, koma desimal
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (hasComma) {
    // Anggap koma sebagai desimal jika hanya muncul sekali di dekat akhir,
    // selain itu anggap sebagai pemisah ribuan.
    final parts = text.split(',');
    if (parts.length == 2 && parts.last.length <= 2) {
      text = text.replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (hasDot) {
    final parts = text.split('.');
    if (parts.length > 2) {
      // Lebih dari satu titik -> semuanya pemisah ribuan.
      text = text.replaceAll('.', '');
    } else if (parts.length == 2 && parts.last.length == 3) {
      // "1.000" khas pemisah ribuan Indonesia.
      text = text.replaceAll('.', '');
    }
    // Jika bentuknya "12.5" (desimal wajar), biarkan apa adanya.
  }

  return double.tryParse(text) ?? 0;
}

/// Ambil representasi teks dari sebuah cell Excel (angka atau string).
String cellText(dynamic cellValue) {
  if (cellValue == null) return '';
  return cellValue.toString();
}

/// Ubah teks bebas (label periode, nomor invoice, dst) jadi nama file yang
/// aman dipakai di semua OS: "/" dan "\" jadi "-", spasi jadi "_", karakter
/// lain yang tidak aman dibuang.
String sanitizeFileName(String label) {
  var text = label.replaceAll(RegExp(r'[\\/]'), '-');
  text = text.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '');
  return text.replaceAll(' ', '_');
}
