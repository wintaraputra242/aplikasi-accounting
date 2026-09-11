import '../models/period.dart';
import '../utils/formatters.dart';

/// Satu poin bernomor pada Analisa Singkat, mis. "1. Pendapatan".
class AnalisaPoin {
  final String judul;
  final String isi;

  const AnalisaPoin({required this.judul, required this.isi});
}

String _joinNama(List<String> nama) {
  if (nama.isEmpty) return '';
  if (nama.length == 1) return nama.first;
  return '${nama.sublist(0, nama.length - 1).join(', ')} dan ${nama.last}';
}

/// Cari poin Pendapatan: kategori dengan nominal terbesar & persentasenya
/// dari total pendapatan, dengan kesimpulan tunai/non-tunai.
AnalisaPoin _poinPendapatan(Period p) {
  final rows = buildPendapatanList(p).where((r) => r.value > 0).toList();
  final total = p.totalPenjualan;

  if (total <= 0 || rows.isEmpty) {
    return const AnalisaPoin(
      judul: 'Pendapatan',
      isi: 'Belum ada data pendapatan pada periode ini.',
    );
  }

  rows.sort((a, b) => b.value.compareTo(a.value));
  final top = rows.first;
  final pct = total == 0 ? 0.0 : top.value / total * 100;
  final metode = top.label == 'Income Cash'
      ? 'transaksi tunai masih menjadi metode pembayaran utama pelanggan'
      : 'transaksi non-tunai masih menjadi metode pembayaran utama pelanggan';

  return AnalisaPoin(
    judul: 'Pendapatan',
    isi: 'Total Pendapatan selama periode berjalan mencapai ${formatRupiah(total)}. '
        'Pendapatan terbesar dari transaksi ${top.label.replaceFirst('Income ', '')} '
        'sebesar ${formatRupiah(top.value)} atau sekitar ${formatPercent(pct)} dari total '
        'pendapatan. Hal ini menunjukan bahwa $metode.',
  );
}

AnalisaPoin _poinFoodCostRatio(Period p) {
  final r = buildRasioList(p).firstWhere((r) => r.nama == 'Food Cost Ratio');
  final ideal = r.isIdeal(r.hasil);
  final isi = ideal
      ? 'Food cost ratio tercatat sebesar ${formatPercent(r.hasil)}, menunjukan pengelolaan '
          'bahan baku masih baik dan masih berada dalam kisaran ideal (${r.standarIdeal}). '
          'Pengendalian persediaan dan waste perlu terus dipertahankan agar rasio tetap stabil.'
      : 'Food cost ratio tercatat sebesar ${formatPercent(r.hasil)}, berada di luar kisaran '
          'ideal (${r.standarIdeal}). Perlu ditinjau kembali pengelolaan bahan baku, porsi, '
          'dan potensi waste supaya rasio ini kembali ke kisaran yang sehat.';
  return AnalisaPoin(judul: 'Food Cost Ratio', isi: isi);
}

AnalisaPoin _poinOperatingExpenseRatio(Period p) {
  final r = buildRasioList(p).firstWhere((r) => r.nama == 'Operating Expense Ratio');
  final ideal = r.isIdeal(r.hasil);

  final beban = buildBebanList(p).where((b) => b.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top3 = beban.take(3).map((b) => b.label.toLowerCase()).toList();
  final komponen = top3.isEmpty ? '' : _joinNama(top3);

  final isi = ideal
      ? 'Operating Expense Ratio sebesar ${formatPercent(r.hasil)}, yang menunjukan biaya '
          'operasional masih dalam batas yang terkendali (${r.standarIdeal}).'
          '${komponen.isEmpty ? '' : ' Komponen terbesar berasal dari $komponen yang merupakan biaya utama operasional usaha.'}'
      : 'Operating Expense Ratio sebesar ${formatPercent(r.hasil)}, berada di luar batas ideal '
          '(${r.standarIdeal}), menunjukan biaya operasional perlu dikendalikan lebih ketat.'
          '${komponen.isEmpty ? '' : ' Komponen terbesar berasal dari $komponen -- perlu jadi fokus utama efisiensi.'}';
  return AnalisaPoin(judul: 'Operating Expense Ratio', isi: isi);
}

AnalisaPoin _poinLaborCostRatio(Period p) {
  final r = buildRasioList(p).firstWhere((r) => r.nama == 'Labor Cost Ratio');
  final ideal = r.isIdeal(r.hasil);
  final isi = ideal
      ? 'Labor cost ratio sebesar ${formatPercent(r.hasil)} masih berada pada tingkat yang '
          'sehat dan efisien terhadap pendapatan (${r.standarIdeal}). Hal ini menunjukan biaya '
          'tenaga kerja masih proporsional dengan tingkat penjualan yang dihasilkan.'
      : 'Labor cost ratio sebesar ${formatPercent(r.hasil)} berada di luar kisaran ideal '
          '(${r.standarIdeal}). Perlu dievaluasi kembali proporsi biaya tenaga kerja terhadap '
          'tingkat penjualan yang dihasilkan.';
  return AnalisaPoin(judul: 'Labor Cost Ratio', isi: isi);
}

AnalisaPoin _poinNetProfitMargin(Period p) {
  final r = buildRasioList(p).firstWhere((r) => r.nama == 'Net Profit Margin');
  final ideal = r.isIdeal(r.hasil);
  final perSeratus = (r.hasil).toStringAsFixed(2).replaceAll('.', ',');
  final dasar = 'Net profit margin sebesar ${formatPercent(r.hasil)}, artinya setiap Rp100 '
      'penjualan menghasilkan laba bersih sekitar Rp$perSeratus setelah dikurangi seluruh '
      'biaya yang telah tercatat.';
  final isi = ideal
      ? '$dasar Ini menunjukan tingkat profitabilitas yang sehat (${r.standarIdeal}). '
          'Kedepannya, fokus utama adalah mempertahankan kontrol biaya, mengurangi potensi '
          'pemborosan, dan menjaga kualitas operasional agar profit yang diperoleh dapat terus '
          'dipertahankan secara stabil.'
      : '$dasar Angka ini berada di luar kisaran ideal (${r.standarIdeal}), sehingga perlu '
          'ditelaah kembali apakah seluruh biaya operasional (perawatan, utilitas, pajak, dan '
          'biaya lainnya) sudah masuk dalam laporan, sekaligus mencari peluang efisiensi biaya '
          'agar profitabilitas membaik.';
  return AnalisaPoin(judul: 'Net Profit Margin', isi: isi);
}

/// Bangun 5 poin Analisa Singkat (Pendapatan, Food Cost Ratio, Operating
/// Expense Ratio, Labor Cost Ratio, Net Profit Margin) mengikuti pola narasi
/// pada laporan contoh, dengan angka & kesimpulan dihitung dinamis dari [p].
List<AnalisaPoin> buildAnalisaSingkat(Period p) => [
      _poinPendapatan(p),
      _poinFoodCostRatio(p),
      _poinOperatingExpenseRatio(p),
      _poinLaborCostRatio(p),
      _poinNetProfitMargin(p),
    ];
