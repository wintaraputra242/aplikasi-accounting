import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/business_profile.dart';
import '../models/invoice.dart';
import '../models/period.dart';
import 'analisa_singkat.dart';
import '../utils/formatters.dart';

// Palet PDF disamakan dengan design.md (teal lama dihapus total, brand
// oranye jadi aksen utama) -- lihat lib/theme/app_colors.dart untuk versi
// Flutter ColorScheme-nya. PDF selalu dicetak di atas kertas putih, jadi
// dipakai langsung nilai "light theme"-nya tanpa varian dark.
final _brandPrimaryPdf = PdfColor.fromHex('#C43E00'); // primary
final _brandSecondaryPdf = PdfColor.fromHex('#44474A'); // secondary (netral gelap)
final _neutralPdf = PdfColor.fromHex('#8C877D'); // outline (netral)
final _successPdf = PdfColor.fromHex('#1B8A5A'); // semantik sukses

/// Ukuran kertas invoice: A4 Landscape (842 x 595 pt), sesuai contoh asli
/// (INV.MANGANA.009.pdf) yang MediaBox-nya persis A4 dibalik mendatar --
/// bukan B5 seperti dugaan awal.
final _invoicePageFormat = PdfPageFormat.a4.landscape;

String _fmtDateLong(DateTime d) => DateFormat('d MMMM yyyy', 'id_ID').format(d);

pw.Widget _sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _brandPrimaryPdf),
      ),
    );

/// Kotak ringkasan kecil di bagian atas halaman 1, mis. "Penjualan: Rp X".
pw.Widget _summaryBox(String label, String value, String? sub, PdfColor color) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
          if (sub != null) pw.Text(sub, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ],
      ),
    ),
  );
}

pw.Widget _summaryStrip(Period p) {
  return pw.Row(
    children: [
      _summaryBox('Penjualan', formatRupiah(p.totalPenjualan), 'Total Pendapatan', _brandPrimaryPdf),
      _summaryBox('Laba Bersih', formatRupiah(p.labaBersih), 'Net Profit',
          p.labaBersih >= 0 ? _successPdf : PdfColors.red700),
      _summaryBox('Food Cost Ratio', formatPercent(p.foodCostRatio), 'Dari Total Pendapatan', _brandSecondaryPdf),
      _summaryBox(
          'Net Profit Margin', formatPercent(p.netProfitMargin), 'Dari Total Pendapatan', _neutralPdf),
      _summaryBox('Operating Expense Ratio', formatPercent(p.operatingExpenseRatio),
          'Dari Total Pendapatan', _brandPrimaryPdf),
    ],
  );
}

pw.Widget _moneyTable(String title, List<List<String>> rows, {String? totalLabel, String? totalValue}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        color: _brandPrimaryPdf,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ),
      pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: {1: pw.Alignment.centerRight},
        headers: const ['Keterangan', 'Rupiah'],
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        data: rows,
      ),
      if (totalLabel != null)
        pw.Container(
          width: double.infinity,
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(totalLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text(totalValue ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _labaBar(String label, double value, PdfColor color) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 6),
    color: color,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text(formatRupiah(value), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    ),
  );
}

pw.Widget _neracaSaldoTable(Period p) {
  final rows = buildNeracaSaldoList(p);
  final totalDebit = rows.fold<double>(0, (a, r) => a + r.debit);
  final totalKredit = rows.fold<double>(0, (a, r) => a + r.kredit);
  return pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: pw.BoxDecoration(color: _brandPrimaryPdf),
    cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
    headers: const ['Akun', 'Debit', 'Kredit'],
    data: [
      ...rows.map((r) => [
            r.akun,
            r.debit == 0 ? '-' : formatRupiah(r.debit),
            r.kredit == 0 ? '-' : formatRupiah(r.kredit),
          ]),
      ['Total', formatRupiah(totalDebit), formatRupiah(totalKredit)],
    ],
  );
}

pw.Widget _rasioTable(Period p) {
  return pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: pw.BoxDecoration(color: _brandPrimaryPdf),
    cellAlignments: {1: pw.Alignment.centerRight},
    headers: const ['Rasio', 'Hasil', 'Standar Ideal F&B'],
    data: buildRasioList(p).map((r) => [r.nama, formatPercent(r.hasil), r.standarIdeal]).toList(),
  );
}

pw.Widget _analisaSingkat(Period p) {
  final poinList = buildAnalisaSingkat(p);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < poinList.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${i + 1}. ${poinList[i].judul}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 2),
              pw.Text(poinList[i].isi, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
    ],
  );
}

/// Bangun file PDF ringkasan satu periode: halaman 1 berisi strip ringkasan
/// + breakdown Pendapatan/HPP/Beban Operasional (mengikuti layout laporan
/// asli), halaman 2 berisi Neraca Saldo, Ringkasan Rasio Keuangan, dan
/// Analisa Singkat.
Future<Uint8List> buildRingkasanPdf(Period p) async {
  final doc = pw.Document();

  pw.Widget header(pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LAPORAN LABA RUGI',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandPrimaryPdf),
          ),
          pw.Text('Periode: ${p.label}', style: const pw.TextStyle(fontSize: 11)),
          pw.Divider(color: _brandPrimaryPdf),
        ],
      );

  final pendapatanRows = buildPendapatanList(p).map((r) => [r.label, formatRupiah(r.value)]).toList();
  final hppRows = [
    ['Persediaan Awal', formatRupiah(p.saldoAwal)],
    ['Pembelian Bahan Baku', formatRupiah(p.totalPembelianBahanBaku)],
    ['Persediaan Akhir', '(${formatRupiah(p.persediaanAkhir)})'],
  ];
  final bebanRows = buildBebanList(p).map((b) => [b.label, formatRupiah(b.value)]).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: header,
      build: (context) => [
        _summaryStrip(p),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _moneyTable('PENDAPATAN', pendapatanRows,
                      totalLabel: 'TOTAL PENDAPATAN', totalValue: formatRupiah(p.totalPenjualan)),
                  pw.SizedBox(height: 10),
                  _moneyTable('HARGA POKOK PENJUALAN (HPP)', hppRows,
                      totalLabel: 'TOTAL HPP', totalValue: formatRupiah(p.hpp)),
                  _labaBar('LABA KOTOR', p.labaKotor, _neutralPdf),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _moneyTable('BEBAN OPERASIONAL', bebanRows,
                      totalLabel: 'TOTAL BEBAN OPERASIONAL', totalValue: formatRupiah(p.totalBeban)),
                  _labaBar('LABA BERSIH', p.labaBersih, p.labaBersih >= 0 ? _successPdf : PdfColors.red700),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: header,
      build: (context) => [
        _sectionTitle('Neraca Saldo'),
        _neracaSaldoTable(p),
        _sectionTitle('Ringkasan Rasio Keuangan'),
        _rasioTable(p),
        _sectionTitle('Analisa Singkat'),
        _analisaSingkat(p),
      ],
    ),
  );

  return doc.save();
}

final _kInfoLabelStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9);
const _kInfoValueStyle = pw.TextStyle(fontSize: 9);
const _kBoxPad = pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4);

/// Rasio lebar:tinggi asli assets/images/mangana_logo_transparent.png (215x84px).
const _kLogoAspectRatio = 215 / 84;

pw.Widget _invoiceHeader(BusinessProfile profile, Uint8List? logoBytes) {
  final left = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        profile.namaUsaha.toUpperCase(),
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _brandSecondaryPdf),
      ),
      if (profile.alamatUsaha.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(profile.alamatUsaha, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ],
  );

  if (logoBytes == null) return left;

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(child: left),
      pw.SizedBox(width: 16),
      pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 100 / _kLogoAspectRatio),
    ],
  );
}

pw.Widget _kepadaBlock(InvoiceData inv) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Kepada :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.SizedBox(height: 4),
      pw.Text(inv.namaPenerima, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      if (inv.alamatPenerima.isNotEmpty)
        pw.Text(inv.alamatPenerima, style: const pw.TextStyle(fontSize: 9)),
    ],
  );
}

/// Tinggi baris standar sel info (header/value) -- dipakai supaya sel value
/// No Invoice yang "menyatu" (lihat di bawah) bisa dibuat pas 3x tinggi ini,
/// sejajar dengan 3 baris (Tanggal Invoice value + Jatuh Tempo header+value)
/// di kolom sebelahnya.
const _kInfoRowHeight = 20.0;

pw.Widget _infoCell(String text, {required bool isHeader, double height = _kInfoRowHeight}) {
  return pw.Container(
    width: double.infinity,
    height: height,
    padding: _kBoxPad,
    decoration: pw.BoxDecoration(
      color: isHeader ? _brandSecondaryPdf : null,
      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
    ),
    child: pw.Text(text, style: isHeader ? _kInfoLabelStyle : _kInfoValueStyle),
  );
}

/// Kotak No Invoice/Tanggal Invoice/Jatuh Tempo, mengikuti contoh asli:
/// kolom "No Invoice" cuma punya header + SATU kotak value yang menyatu
/// (rowspan) setinggi 3 baris kolom sebelah -- bukan tabel 2x4 dengan sel
/// kosong di bawah nomor invoice.
pw.Widget _invoiceInfoTable(InvoiceData inv) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          children: [
            _infoCell('No Invoice :', isHeader: true),
            _infoCell(inv.noInvoice, isHeader: false, height: _kInfoRowHeight * 3),
          ],
        ),
      ),
      pw.Expanded(
        child: pw.Column(
          children: [
            _infoCell('Tanggal Invoice :', isHeader: true),
            _infoCell(_fmtDateLong(inv.tanggalInvoice), isHeader: false),
            _infoCell('Jatuh Tempo :', isHeader: true),
            _infoCell(_fmtDateLong(inv.jatuhTempo), isHeader: false),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _invoiceItemsTable(InvoiceData inv) {
  return pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
    headerDecoration: pw.BoxDecoration(color: _brandSecondaryPdf),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.center,
    headerAlignment: pw.Alignment.center,
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headers: const ['No', 'Keterangan', 'Jumlah', 'Harga', 'Total'],
    data: inv.items.asMap().entries.map((e) {
      final i = e.key;
      final item = e.value;
      return [
        '${i + 1}',
        item.keterangan,
        '${item.jumlah}',
        formatRupiah(item.harga),
        formatRupiah(item.total),
      ];
    }).toList(),
  );
}

pw.Widget _kvRow(String label, String value, {double labelWidth = 90, bool valueBold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: labelWidth,
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Text(
          ': $value',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: valueBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

/// Lebar kolom label dibuat cukup lebar supaya "Metode Pembayaran" muat satu
/// baris (tidak turun ke bawah), dan value ikut di-bold sesuai contoh asli.
pw.Widget _pembayaranBox(BusinessProfile profile) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    color: _brandSecondaryPdf,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kvRow('Metode Pembayaran', profile.metodePembayaran, labelWidth: 110, valueBold: true),
        _kvRow('Nama Bank', profile.namaBank, labelWidth: 110, valueBold: true),
        _kvRow('Akun', profile.namaAkunBank, labelWidth: 110, valueBold: true),
        _kvRow('No. Akun', profile.noRekening, labelWidth: 110, valueBold: true),
      ],
    ),
  );
}

/// Kotak kontak person di pojok kanan bawah invoice -- ini tambahan yang
/// belum ada di contoh PDF acuan. Hanya dirender kalau nama/no kontak sudah
/// diisi di Profil Usaha.
pw.Widget? _kontakPersonBox(BusinessProfile profile) {
  if (profile.namaKontak.trim().isEmpty && profile.noKontak.trim().isEmpty) return null;
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _brandSecondaryPdf, width: 1),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Kontak Person',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: _brandSecondaryPdf),
        ),
        pw.SizedBox(height: 3),
        if (profile.namaKontak.isNotEmpty) _kvRow('Nama', profile.namaKontak),
        if (profile.noKontak.isNotEmpty) _kvRow('No. WA/Telp', profile.noKontak),
      ],
    ),
  );
}

/// Bangun file PDF invoice, mengikuti layout contoh yang diberikan (header
/// usaha, kotak No Invoice/Tanggal/Jatuh Tempo, tabel item, total tagihan,
/// kotak info pembayaran) ditambah kotak kontak person di pojok kanan bawah
/// yang belum ada di contoh aslinya. Kertas ukuran B5 sesuai permintaan.
Future<Uint8List> buildInvoicePdf(BusinessProfile profile, InvoiceData inv) async {
  final doc = pw.Document();
  final kontakBox = _kontakPersonBox(profile);

  Uint8List? logoBytes;
  try {
    final data = await rootBundle.load('assets/images/mangana_logo_transparent.png');
    logoBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    logoBytes = null;
  }

  doc.addPage(
    pw.Page(
      pageFormat: _invoicePageFormat,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _invoiceHeader(profile, logoBytes),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _kepadaBlock(inv)),
                pw.SizedBox(width: 16),
                pw.Expanded(child: _invoiceInfoTable(inv)),
              ],
            ),
            pw.SizedBox(height: 20),
            _invoiceItemsTable(inv),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Tagihan : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(
                  formatRupiah(inv.totalTagihan),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 3, child: _pembayaranBox(profile)),
                if (kontakBox != null) ...[
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 2, child: kontakBox),
                ],
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.black, thickness: 1),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '*Mohon kirimkan bukti transfer',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}
