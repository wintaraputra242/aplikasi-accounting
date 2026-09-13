import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/arus_kas.dart';
import '../models/period.dart';
import '../models/posisi_keuangan.dart';
import '../services/analisa_singkat.dart';
import '../theme/app_semantic_colors.dart';
import '../utils/formatters.dart';
import 'common_widgets.dart';

/// Widget-widget laporan yang dipakai ulang di tab Ringkasan (per periode),
/// tab Neraca Saldo, dan layar Ringkasan Tahunan (agregat) -- semuanya
/// menerima [Period] biasa, jadi bisa dikasih periode asli maupun hasil
/// [aggregateYear].

/// Warna judul kontras otomatis di atas slice pie chart -- supaya tetap
/// terbaca putih/gelap baik di light maupun dark theme walau warna slice-nya
/// berubah kecerahan antar tema (mis. `primary` terang di dark theme).
Color _onSliceColor(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87;

/// Kartu besar Laba/Rugi Bersih -- angka yang paling ingin dilihat pemilik
/// usaha begitu buka laporan. [title] bisa diganti, mis. "Laba Bersih Tahun
/// 2026" di Ringkasan Tahunan.
class NetProfitCard extends StatelessWidget {
  final Period period;
  final String title;

  const NetProfitCard({super.key, required this.period, this.title = 'Net Profit (Laba Bersih)'});

  @override
  Widget build(BuildContext context) {
    final positive = period.labaBersih >= 0;
    final semantic = context.semanticColors;
    final color = positive ? semantic.success : Theme.of(context).colorScheme.error;
    final bg = color.withValues(alpha: 0.12);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(positive ? Icons.trending_up : Icons.trending_down, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(period.labaBersih),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    'Margin: ${formatPercent(period.netProfitMargin)}',
                    style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut chart komposisi Total Penjualan: HPP, Beban Operasional, dan Laba
/// Bersih. Kalau laba bersih negatif, slice-nya di-clamp ke 0 (biar chart
/// tidak error) dan ditambahkan catatan rugi di bawah chart.
class _KomposisiChart extends StatelessWidget {
  final Period period;

  const _KomposisiChart({required this.period});

  @override
  Widget build(BuildContext context) {
    final total = period.totalPenjualan;
    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Belum ada data penjualan untuk periode ini.'),
      );
    }

    final hpp = period.hpp.clamp(0.0, total);
    final beban = period.totalBeban.clamp(0.0, total);
    final laba = period.labaBersih < 0 ? 0.0 : period.labaBersih;

    Widget legendItem(Color color, String label, double value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: ${formatRupiah(value)}', style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    String pct(double value) => formatPercent(total == 0 ? 0 : value / total * 100);

    // Palet dibatasi ke primary + secondary + 1 nuansa netral (bukan warna
    // pelangi acak) supaya chart ini terasa satu sistem dengan sisa app --
    // lihat design.md §4 "Ringkasan Tahunan". Laba Bersih (yang paling ingin
    // dilihat pemilik usaha) dapat warna brand primary sebagai penekanan.
    final scheme = Theme.of(context).colorScheme;
    final colorHpp = scheme.outline;
    final colorBeban = scheme.secondary;
    final colorLaba = scheme.primary;

    PieChartSectionData section(double value, Color color) => PieChartSectionData(
          value: value,
          color: color,
          title: pct(value),
          radius: 50,
          titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _onSliceColor(color)),
        );

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                section(hpp, colorHpp),
                section(beban, colorBeban),
                section(laba, colorLaba),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            legendItem(colorHpp, 'HPP', hpp),
            legendItem(colorBeban, 'Beban Operasional', beban),
            legendItem(colorLaba, 'Laba Bersih', laba),
          ],
        ),
        if (period.labaBersih < 0) ...[
          const SizedBox(height: 8),
          Text(
            'Rugi Bersih: ${formatRupiah(period.labaBersih)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// [SectionCard] berisi donut chart komposisi penjualan (lihat [_KomposisiChart]).
class KomposisiPenjualanCard extends StatelessWidget {
  final Period period;

  const KomposisiPenjualanCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Komposisi Penjualan',
      icon: Icons.donut_large,
      child: _KomposisiChart(period: period),
    );
  }
}

/// [SectionCard] breakdown 9 kategori Pendapatan + total.
class PendapatanCard extends StatelessWidget {
  final Period period;

  const PendapatanCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Pendapatan',
      icon: Icons.trending_up,
      child: Column(
        children: [
          for (final r in buildPendapatanList(period)) MoneyDisplayRow(label: r.label, value: r.value),
          const Divider(),
          MoneyDisplayRow(label: 'Total Pendapatan', value: period.totalPenjualan, bold: true),
        ],
      ),
    );
  }
}

/// [SectionCard] Harga Pokok Penjualan (Persediaan Awal/Pembelian/Akhir) + Laba Kotor.
class HppCard extends StatelessWidget {
  final Period period;

  const HppCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Harga Pokok Penjualan (HPP)',
      icon: Icons.inventory_2,
      child: Column(
        children: [
          MoneyDisplayRow(label: 'Persediaan Awal', value: period.saldoAwal),
          MoneyDisplayRow(label: 'Pembelian Bahan Baku', value: period.totalPembelianBahanBaku),
          MoneyDisplayRow(label: 'Persediaan Akhir', value: -period.persediaanAkhir),
          const Divider(),
          MoneyDisplayRow(label: 'Total HPP', value: period.hpp, bold: true),
          const SizedBox(height: 8),
          MoneyDisplayRow(
            label: 'Laba Kotor',
            value: period.labaKotor,
            bold: true,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// [SectionCard] breakdown 19 baris Beban Operasional + total.
class BebanOperasionalCard extends StatelessWidget {
  final Period period;

  const BebanOperasionalCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Beban Operasional',
      icon: Icons.receipt_long,
      child: Column(
        children: [
          for (final b in buildBebanList(period)) MoneyDisplayRow(label: b.label, value: b.value),
          const Divider(),
          MoneyDisplayRow(label: 'Total Beban Operasional', value: period.totalBeban, bold: true),
        ],
      ),
    );
  }
}

/// [SectionCard] ringkasan Laba Rugi (Penjualan - HPP - Beban = Laba Bersih).
class LabaRugiCard extends StatelessWidget {
  final Period period;

  const LabaRugiCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Laba Rugi',
      icon: Icons.account_balance,
      child: Column(
        children: [
          MoneyDisplayRow(label: 'Total Penjualan', value: period.totalPenjualan),
          MoneyDisplayRow(label: '- HPP (Pembelian)', value: period.hpp),
          const Divider(),
          MoneyDisplayRow(label: 'Laba Kotor', value: period.labaKotor, bold: true),
          const SizedBox(height: 8),
          MoneyDisplayRow(label: '- Beban Operasional', value: period.totalBeban),
          const Divider(),
          MoneyDisplayRow(
            label: 'Laba Bersih',
            value: period.labaBersih,
            bold: true,
            color: period.labaBersih >= 0
                ? context.semanticColors.success
                : Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _RasioTable extends StatelessWidget {
  final List<RasioInfo> rasioList;

  const _RasioTable({required this.rasioList});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        ),
        columns: const [
          DataColumn(label: Text('Rasio')),
          DataColumn(label: Text('Hasil')),
          DataColumn(label: Text('Standar Ideal F&B')),
        ],
        rows: rasioList.map((r) {
          final ideal = r.isIdeal(r.hasil);
          final semantic = context.semanticColors;
          final color = ideal ? semantic.success : semantic.warning;
          return DataRow(
            cells: [
              DataCell(Text(r.nama)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ideal ? Icons.check_circle : Icons.error_outline, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      formatPercent(r.hasil),
                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ),
              DataCell(Text(r.standarIdeal)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// [SectionCard] tabel Ringkasan Rasio Keuangan dibandingkan standar ideal F&B.
class RasioKeuanganCard extends StatelessWidget {
  final Period period;

  const RasioKeuanganCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Ringkasan Rasio Keuangan',
      icon: Icons.pie_chart,
      child: _RasioTable(rasioList: buildRasioList(period)),
    );
  }
}

class _AnalisaSingkatView extends StatelessWidget {
  final List<AnalisaPoin> poin;

  const _AnalisaSingkatView({required this.poin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < poin.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${poin[i].judul}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(poin[i].isi, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
      ],
    );
  }
}

/// [SectionCard] narasi Analisa Singkat (lihat [buildAnalisaSingkat]).
class AnalisaSingkatCard extends StatelessWidget {
  final Period period;

  const AnalisaSingkatCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Analisa Singkat',
      icon: Icons.article,
      child: _AnalisaSingkatView(poin: buildAnalisaSingkat(period)),
    );
  }
}

class _NeracaSaldoTable extends StatelessWidget {
  final List<NeracaSaldoRow> rows;
  final double totalDebit;
  final double totalKredit;

  const _NeracaSaldoTable({
    required this.rows,
    required this.totalDebit,
    required this.totalKredit,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        ),
        columns: const [
          DataColumn(label: Text('Akun')),
          DataColumn(label: Text('Debit'), numeric: true),
          DataColumn(label: Text('Kredit'), numeric: true),
        ],
        rows: [
          ...rows.map(
            (r) => DataRow(
              cells: [
                DataCell(Text(r.akun)),
                DataCell(Text(r.debit == 0 ? '-' : formatRupiah(r.debit))),
                DataCell(Text(r.kredit == 0 ? '-' : formatRupiah(r.kredit))),
              ],
            ),
          ),
          DataRow(
            cells: [
              DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: primary))),
              DataCell(Text(
                formatRupiah(totalDebit),
                style: TextStyle(fontWeight: FontWeight.bold, color: primary),
              )),
              DataCell(Text(
                formatRupiah(totalKredit),
                style: TextStyle(fontWeight: FontWeight.bold, color: primary),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

/// [SectionCard] tabel Neraca Saldo (lihat [buildNeracaSaldoList]).
class NeracaSaldoCard extends StatelessWidget {
  final Period period;

  const NeracaSaldoCard({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    final rows = buildNeracaSaldoList(period);
    final totalDebit = rows.fold<double>(0, (a, r) => a + r.debit);
    final totalKredit = rows.fold<double>(0, (a, r) => a + r.kredit);

    return SectionCard(
      title: 'Neraca Saldo',
      icon: Icons.balance,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada data. Isi tab Penjualan, Pembelian, dan Beban dulu.'),
            )
          : _NeracaSaldoTable(rows: rows, totalDebit: totalDebit, totalKredit: totalKredit),
    );
  }
}

/// Baris label - nominal di dalam laporan berjenjang (Neraca/Arus Kas), mis.
/// satu akun di dalam kelompok Aset Lancar. Beda dari [MoneyDisplayRow]:
/// ukuran font lebih kecil & rata dengan indentasi kelompok, dipakai untuk
/// baris rincian bukan baris total.
class _SubRow extends StatelessWidget {
  final String label;
  final double value;

  const _SubRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(formatRupiah(value), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _SelisihBanner extends StatelessWidget {
  final double selisih;
  final String message;

  const _SelisihBanner({required this.selisih, required this.message});

  @override
  Widget build(BuildContext context) {
    // Toleransi kecil untuk pembulatan (bukan bug pembulatan matematis di
    // atas Rp1) -- selisih di bawah ini dianggap "balance".
    final balanced = selisih.abs() < 1;
    final semantic = context.semanticColors;
    final color = balanced ? semantic.success : semantic.warning;
    final bg = color.withValues(alpha: 0.12);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(balanced ? Icons.check_circle : Icons.warning_amber, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              balanced ? 'Balance (Selisih ${formatRupiah(selisih)}).' : '$message ${formatRupiah(selisih)}.',
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// [SectionCard] Laporan Posisi Keuangan (Balance Sheet) -- lihat
/// [buildPosisiKeuangan]. Assets ditampilkan lebih dulu, lalu Liabilities +
/// Equity, ditutup dengan indikator selisih supaya ketidaksesuaian saldo
/// (input yang belum lengkap/konsisten) langsung terlihat, bukan
/// disembunyikan.
class PosisiKeuanganCard extends StatelessWidget {
  final PosisiKeuanganData data;

  const PosisiKeuanganCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SectionCard(
      title: 'Laporan Posisi Keuangan (Neraca)',
      icon: Icons.account_balance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ASET', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Aset Lancar',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final r in data.asetLancar)
            if (r.value != 0) _SubRow(label: r.label, value: r.value),
          MoneyDisplayRow(label: 'Total Aset Lancar', value: data.totalAsetLancar, bold: true),
          const SizedBox(height: 8),
          Text('Aset Tetap (Nilai Buku)',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final r in data.asetTetap) _SubRow(label: r.label, value: r.value),
          _SubRow(label: 'Harga Perolehan', value: data.totalHargaPerolehanAsetTetap),
          _SubRow(label: 'Akumulasi Penyusutan', value: -data.totalAkumulasiPenyusutan),
          MoneyDisplayRow(label: 'Total Aset Tetap (NBV)', value: data.totalAsetTetap, bold: true),
          const Divider(),
          MoneyDisplayRow(label: 'TOTAL ASET', value: data.totalAset, bold: true, color: primary),
          const SizedBox(height: 16),
          const Text('LIABILITAS', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final r in data.liabilitas)
            if (r.value != 0) _SubRow(label: r.label, value: r.value),
          MoneyDisplayRow(label: 'Total Liabilitas', value: data.totalLiabilitas, bold: true),
          const SizedBox(height: 16),
          const Text('EKUITAS', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final r in data.ekuitas) _SubRow(label: r.label, value: r.value),
          MoneyDisplayRow(label: 'Total Ekuitas', value: data.totalEkuitas, bold: true),
          const Divider(),
          MoneyDisplayRow(
            label: 'TOTAL LIABILITAS + EKUITAS',
            value: data.totalLiabilitasEkuitas,
            bold: true,
            color: primary,
          ),
          _SelisihBanner(
            selisih: data.selisih,
            message: 'Belum balance -- Aset dengan Liabilitas+Ekuitas selisih',
          ),
        ],
      ),
    );
  }
}

/// [SectionCard] Laporan Arus Kas (metode tidak langsung) -- lihat
/// [buildArusKas].
class ArusKasCard extends StatelessWidget {
  final ArusKasData data;

  const ArusKasCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SectionCard(
      title: 'Laporan Arus Kas',
      icon: Icons.swap_vert,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Arus Kas dari Operasi', style: TextStyle(fontWeight: FontWeight.bold)),
          _SubRow(label: 'Laba Bersih', value: data.labaBersih),
          _SubRow(label: '+ Penyusutan (non-kas)', value: data.penyusutan),
          _SubRow(label: '- Kenaikan Piutang', value: -data.deltaPiutang),
          _SubRow(label: '- Kenaikan Persediaan', value: -data.deltaPersediaan),
          _SubRow(label: '- Kenaikan Prepaid', value: -data.deltaPrepaid),
          _SubRow(label: '+ Kenaikan Hutang Usaha', value: data.deltaHutangUsaha),
          _SubRow(label: '+ Kenaikan Hutang Gaji', value: data.deltaHutangGaji),
          _SubRow(label: '+ Kenaikan Hutang Pajak', value: data.deltaHutangPajak),
          _SubRow(label: '+ Kenaikan Hutang Service Charge', value: data.deltaHutangServiceCharge),
          _SubRow(label: '+ Kenaikan Hutang Lain-lain', value: data.deltaHutangLainLain),
          _SubRow(
            label: '+ Kenaikan Pendapatan Diterima Dimuka',
            value: data.deltaPendapatanDiterimaDimuka,
          ),
          MoneyDisplayRow(label: 'Kas Bersih dari Operasi', value: data.totalOperasi, bold: true),
          const SizedBox(height: 16),
          const Text('Arus Kas dari Investasi', style: TextStyle(fontWeight: FontWeight.bold)),
          _SubRow(label: '- Pembelian Aset Tetap', value: -data.pembelianAsetTetap),
          MoneyDisplayRow(label: 'Kas Bersih dari Investasi', value: data.totalInvestasi, bold: true),
          const SizedBox(height: 16),
          const Text('Arus Kas dari Pendanaan', style: TextStyle(fontWeight: FontWeight.bold)),
          _SubRow(label: '+ Setoran Modal', value: data.modalDisetor),
          _SubRow(label: '- Prive/Pengambilan Owner', value: -data.prive),
          _SubRow(label: '+/- Perubahan Pinjaman', value: data.deltaPinjaman),
          MoneyDisplayRow(label: 'Kas Bersih dari Pendanaan', value: data.totalPendanaan, bold: true),
          const Divider(),
          MoneyDisplayRow(
            label: 'Kenaikan (Penurunan) Kas Bersih',
            value: data.netChangeKas,
            bold: true,
            color: primary,
          ),
          MoneyDisplayRow(label: 'Saldo Kas Awal Periode', value: data.saldoKasAwal),
          MoneyDisplayRow(
            label: 'Saldo Kas Akhir (Hasil Hitungan)',
            value: data.saldoKasAkhirHitung,
            bold: true,
          ),
          MoneyDisplayRow(
            label: 'Saldo Kas Akhir (Input Aktual)',
            value: data.saldoKasAkhirAktual,
            bold: true,
          ),
          _SelisihBanner(
            selisih: data.selisih,
            message: 'Saldo Kas aktual dengan hasil hitungan Arus Kas selisih',
          ),
        ],
      ),
    );
  }
}
