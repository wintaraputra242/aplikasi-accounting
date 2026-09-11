import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/business_profile.dart';
import '../models/period.dart';
import '../services/excel_export.dart';
import '../services/pdf_export.dart';
import '../utils/formatters.dart';
import '../widgets/quick_nav.dart';
import '../widgets/common_widgets.dart';
import '../widgets/report_widgets.dart';

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Layar Ringkasan Tahunan: jumlahkan semua periode dalam satu tahun jadi
/// satu laporan (sama isinya seperti tab Neraca Saldo & Ringkasan per
/// periode -- lihat `lib/widgets/report_widgets.dart`), ditambah kartu omset
/// tahun berjalan dan grafik tren omset bulanan.
class RingkasanTahunanScreen extends StatefulWidget {
  const RingkasanTahunanScreen({super.key});

  @override
  State<RingkasanTahunanScreen> createState() => _RingkasanTahunanScreenState();
}

class _RingkasanTahunanScreenState extends State<RingkasanTahunanScreen> {
  bool _loading = true;
  bool _exportingExcel = false;
  bool _exportingPdf = false;
  List<Period> _allPeriods = [];
  BusinessProfile _profile = const BusinessProfile();
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseHelper.instance.getAllPeriods(),
      DatabaseHelper.instance.getBusinessProfile(),
    ]);
    if (!mounted) return;
    final periods = results[0] as List<Period>;
    setState(() {
      _allPeriods = periods;
      _profile = results[1] as BusinessProfile;
      if (periods.isNotEmpty) {
        _selectedYear = periods.map((p) => p.startDate.year).reduce(max);
      }
      _loading = false;
    });
  }

  List<int> get _availableYears {
    final years = _allPeriods.map((p) => p.startDate.year).toSet();
    years.add(DateTime.now().year);
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<Period> get _periodsInSelectedYear =>
      _allPeriods.where((p) => p.startDate.year == _selectedYear).toList();

  Future<void> _exportExcel(Period agregat) async {
    setState(() => _exportingExcel = true);
    try {
      final bytes = buildRingkasanExcel(agregat);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Ringkasan Tahunan Excel',
        fileName: 'Ringkasan_${sanitizeFileName(agregat.label)}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat Excel: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _exportPdf(Period agregat) async {
    setState(() => _exportingPdf = true);
    try {
      final bytes = await buildRingkasanPdf(agregat);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Ringkasan Tahunan PDF',
        fileName: 'Ringkasan_${sanitizeFileName(agregat.label)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Tahunan'),
        actions: const [QuickNavButton(current: QuickNavTarget.ringkasanTahunan)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final periodsInYear = _periodsInSelectedYear;
    final agregat = aggregateYear(_selectedYear, periodsInYear);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Pilih Tahun',
          icon: Icons.calendar_today,
          child: DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: _availableYears
                .map((y) => DropdownMenuItem(value: y, child: Text('Tahun $y')))
                .toList(),
            onChanged: (y) {
              if (y != null) setState(() => _selectedYear = y);
            },
          ),
        ),
        if (periodsInYear.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text('Belum ada data periode di tahun ini.'),
          )
        else ...[
          SectionCard(
            title: 'Export Laporan',
            icon: Icons.ios_share,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportingExcel ? null : () => _exportExcel(agregat),
                  icon: _exportingExcel
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.grid_on),
                  label: Text(_exportingExcel ? 'Menyimpan...' : 'Export Excel'),
                ),
                FilledButton.icon(
                  onPressed: _exportingPdf ? null : () => _exportPdf(agregat),
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_exportingPdf ? 'Menyimpan...' : 'Export PDF'),
                ),
              ],
            ),
          ),
          _OmsetCard(period: agregat, year: _selectedYear),
          NetProfitCard(period: agregat, title: 'Laba Bersih Tahun $_selectedYear'),
          SectionCard(
            title: 'Tren Omset Bulanan',
            icon: Icons.show_chart,
            child: _OmsetTrendChart(periodsInYear: periodsInYear),
          ),
          SectionCard(
            title: 'Laba Rugi Bulanan (Jan - Des)',
            icon: Icons.table_chart,
            child: _MonthlyPnlTable(periodsInYear: periodsInYear, yearTotal: agregat),
          ),
          KomposisiPenjualanCard(period: agregat),
          PendapatanCard(period: agregat),
          HppCard(period: agregat),
          BebanOperasionalCard(period: agregat),
          LabaRugiCard(period: agregat),
          NeracaSaldoCard(period: agregat),
          RasioKeuanganCard(period: agregat),
          AnalisaSingkatCard(period: agregat),
          _AlokasiLabaCard(
            agregat: agregat,
            profile: _profile,
            jumlahPeriode: periodsInYear.length,
          ),
        ],
      ],
    );
  }
}

/// Kartu besar Total Omset (Pendapatan) satu tahun penuh.
class _OmsetCard extends StatelessWidget {
  final Period period;
  final int year;

  const _OmsetCard({required this.period, required this.year});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.point_of_sale, color: primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Omset Tahun $year', style: TextStyle(fontSize: 13, color: primary)),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(period.totalPenjualan),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
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

String _compactRupiah(double v) {
  if (v < 0) return '-${_compactRupiah(-v)}';
  if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}M';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
  return v.toStringAsFixed(0);
}

/// Bar chart tren Total Penjualan per bulan (Jan-Des) dalam tahun terpilih.
/// Periode custom (bukan bulan kalender) dikelompokkan ke bulan dari
/// `startDate`-nya.
class _OmsetTrendChart extends StatelessWidget {
  final List<Period> periodsInYear;

  const _OmsetTrendChart({required this.periodsInYear});

  @override
  Widget build(BuildContext context) {
    final monthly = List<double>.filled(12, 0);
    for (final p in periodsInYear) {
      monthly[p.startDate.month - 1] += p.totalPenjualan;
    }
    final maxVal = monthly.reduce(max);

    if (maxVal <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Belum ada data penjualan untuk tahun ini.'),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final topMonthIndex = monthly.indexOf(maxVal);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_monthAbbrev[value.toInt()], style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${_monthAbbrev[group.x]}\n${formatRupiah(rod.toY)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              barGroups: List.generate(
                12,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: monthly[i],
                      color: primary,
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Omset tertinggi: ${_monthAbbrev[topMonthIndex]} (${_compactRupiah(maxVal)})',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Kalkulator Alokasi Laba tahunan: Laba Bersih tahun berjalan dibagi ke
/// Reserve/Maintenance/R&D (persentase dari Omset Bersih di luar Service
/// Charge -- SC adalah hak karyawan/kewajiban 20.3, bukan omset usaha;
/// persentase diatur sekali di Profil Usaha) + sisanya ke Owner
/// Distribution, plus perbandingan terhadap Target Cash Reserve (rata-rata
/// Beban Operasional bulanan x N bulan).
class _AlokasiLabaCard extends StatelessWidget {
  final Period agregat;
  final BusinessProfile profile;
  final int jumlahPeriode;

  const _AlokasiLabaCard({
    required this.agregat,
    required this.profile,
    required this.jumlahPeriode,
  });

  @override
  Widget build(BuildContext context) {
    final omset = agregat.omsetBersihExclSC;
    final labaBersih = agregat.labaBersih;
    final reserve = omset * profile.pctReserve / 100;
    final maintenance = omset * profile.pctMaintenance / 100;
    final nextBusiness = omset * profile.pctNextBusinessFund / 100;
    final ownerDistribution = labaBersih - reserve - maintenance - nextBusiness;

    final avgBebanBulanan = jumlahPeriode == 0 ? 0.0 : agregat.totalBeban / jumlahPeriode;
    final targetCashReserve = avgBebanBulanan * profile.cashReserveBulan;

    return SectionCard(
      title: 'Alokasi Laba',
      icon: Icons.pie_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyDisplayRow(label: 'Laba Bersih Tahun Ini', value: labaBersih, bold: true),
          const Divider(),
          MoneyDisplayRow(
            label: 'Reserve (${profile.pctReserve.toStringAsFixed(profile.pctReserve == profile.pctReserve.roundToDouble() ? 0 : 2)}% Omset excl. SC)',
            value: reserve,
          ),
          MoneyDisplayRow(
            label: 'Maintenance (${profile.pctMaintenance.toStringAsFixed(profile.pctMaintenance == profile.pctMaintenance.roundToDouble() ? 0 : 2)}% Omset excl. SC)',
            value: maintenance,
          ),
          MoneyDisplayRow(
            label: 'R&D (${profile.pctNextBusinessFund.toStringAsFixed(profile.pctNextBusinessFund == profile.pctNextBusinessFund.roundToDouble() ? 0 : 2)}% Omset excl. SC)',
            value: nextBusiness,
          ),
          MoneyDisplayRow(
            label: 'Owner Distribution (sisa)',
            value: ownerDistribution,
            bold: true,
            color: ownerDistribution < 0 ? Colors.red : null,
          ),
          const Divider(),
          MoneyDisplayRow(
            label: 'Target Cash Reserve (${profile.cashReserveBulan}x rata-rata Beban Bulanan)',
            value: targetCashReserve,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Persentase dihitung dari Total Penjualan (Omset), bukan dari '
              'nominal Laba Bersih. Ubah persentase di menu titik tiga > '
              'Profil Usaha.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris beban operasional yang ditampilkan di [_MonthlyPnlTable], mengikuti
/// urutan kategori yang sama seperti `buildBebanList` di
/// `lib/models/period.dart` (tanpa akun tambahan dinamis -- itu digabung
/// jadi satu baris "Akun Tambahan" supaya kolom tiap bulan tetap sejajar
/// walau nama akun tambahan beda-beda antar bulan).
const _monthlyBebanRows = <(String, double Function(Period))>[
  ('Gaji Karyawan', _bebanGajiKaryawan),
  ('Listrik', _bebanListrikTotal),
  ('Supplies & Cleaning', _bebanSuppliesCleaning),
  ('MDR QRIS', _bebanMdrQris),
  ('MDR EDC', _bebanMdrEdc),
  ('MDR ESB', _bebanMdrEsb),
  ('MDR Go-Food', _bebanMdrGofood),
  ('MDR Grab-Food', _bebanMdrGrabfood),
  ('Marketing', _bebanMarketing),
  ('Biaya Adm Transfer', _bebanAdmTransfer),
  ('Biaya Kartu Debit', _bebanKartuDebit),
  ('Biaya Admin Rekening', _bebanAdminRekening),
  ('Pajak Rekening', _bebanPajakRekening),
  ('Lain-Lain', _bebanLainLain),
  ('Biaya Akomodasi', _bebanBiayaAkomodasi),
  ('Biaya Service Karyawan', _bebanBiayaServiceKaryawan),
  ('Penyusutan Bar', _bebanPenyusutanBar),
  ('Penyusutan Kitchen', _bebanPenyusutanKitchen),
  ('Penyusutan Furniture Area', _bebanPenyusutanFurnitureArea),
  ('Penyusutan Office', _bebanPenyusutanOffice),
  ('Waste/Susut Bahan Baku', _bebanWasteBahanBaku),
  ('Akun Tambahan', _bebanCustom),
];

double _bebanGajiKaryawan(Period p) => p.bebanGajiKaryawan;
double _bebanListrikTotal(Period p) => p.bebanListrikTotal;
double _bebanSuppliesCleaning(Period p) => p.bebanSuppliesCleaning;
double _bebanMdrQris(Period p) => p.bebanMdrQris;
double _bebanMdrEdc(Period p) => p.bebanMdrEdc;
double _bebanMdrEsb(Period p) => p.bebanMdrEsb;
double _bebanMdrGofood(Period p) => p.bebanMdrGofood;
double _bebanMdrGrabfood(Period p) => p.bebanMdrGrabfood;
double _bebanMarketing(Period p) => p.bebanMarketing;
double _bebanAdmTransfer(Period p) => p.bebanAdmTransfer;
double _bebanKartuDebit(Period p) => p.bebanKartuDebit;
double _bebanAdminRekening(Period p) => p.bebanAdminRekening;
double _bebanPajakRekening(Period p) => p.bebanPajakRekening;
double _bebanLainLain(Period p) => p.bebanLainLain;
double _bebanBiayaAkomodasi(Period p) => p.bebanBiayaAkomodasi;
double _bebanBiayaServiceKaryawan(Period p) => p.bebanBiayaServiceKaryawan;
double _bebanPenyusutanBar(Period p) => p.bebanPenyusutanBar;
double _bebanPenyusutanKitchen(Period p) => p.bebanPenyusutanKitchen;
double _bebanPenyusutanFurnitureArea(Period p) => p.bebanPenyusutanFurnitureArea;
double _bebanPenyusutanOffice(Period p) => p.bebanPenyusutanOffice;
double _bebanWasteBahanBaku(Period p) => p.bebanWasteBahanBaku;
double _bebanCustom(Period p) => p.customExpenseItems.fold(0.0, (a, i) => a + i.value);

/// Tabel matriks Laba Rugi bulanan: baris = Revenue/HPP/Gross Profit/tiap
/// kategori Beban/Net Profit, kolom = Jan-Des + Total tahun terpilih. Data
/// per bulan didapat dengan mengelompokkan [periodsInYear] berdasarkan bulan
/// `startDate` lalu dijumlahkan lewat `aggregateYear` (fungsi yang sama
/// dipakai untuk agregat tahunan), jadi tidak perlu logika penjumlahan baru.
class _MonthlyPnlTable extends StatelessWidget {
  final List<Period> periodsInYear;
  final Period yearTotal;

  const _MonthlyPnlTable({required this.periodsInYear, required this.yearTotal});

  @override
  Widget build(BuildContext context) {
    final monthly = List<Period>.generate(
      12,
      (i) => aggregateYear(
        0,
        periodsInYear.where((p) => p.startDate.month == i + 1).toList(),
      ),
    );

    const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    const valueStyle = TextStyle(fontSize: 12);
    const boldValueStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

    DataColumn col(String text) => DataColumn(
          label: Text(text, style: labelStyle),
          numeric: true,
        );

    DataRow row(String label, double Function(Period) value, {bool bold = false}) {
      final style = bold ? boldValueStyle : valueStyle;
      return DataRow(cells: [
        DataCell(Text(label, style: bold ? labelStyle : valueStyle)),
        for (final p in monthly)
          DataCell(Text(_compactRupiah(value(p)), style: style)),
        DataCell(Text(_compactRupiah(value(yearTotal)), style: style)),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 32,
        columns: [
          DataColumn(label: Text('Kategori', style: labelStyle)),
          for (final m in _monthAbbrev) col(m),
          col('Total'),
        ],
        rows: [
          row('Total Pendapatan', (p) => p.totalPenjualan, bold: true),
          row('HPP', (p) => p.hpp),
          row('Laba Kotor', (p) => p.labaKotor, bold: true),
          for (final r in _monthlyBebanRows) row(r.$1, r.$2),
          row('Total Beban', (p) => p.totalBeban, bold: true),
          row('Laba Bersih', (p) => p.labaBersih, bold: true),
        ],
      ),
    );
  }
}
