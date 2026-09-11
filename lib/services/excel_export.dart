import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/period.dart';
import 'analisa_singkat.dart';
import '../utils/formatters.dart';

final _headerStyle = CellStyle(
  bold: true,
  fontColorHex: ExcelColor.white,
  backgroundColorHex: ExcelColor.fromHexString('#00796B'),
  horizontalAlign: HorizontalAlign.Center,
  verticalAlign: VerticalAlign.Center,
);

final _boldStyle = CellStyle(bold: true);

Sheet _freshSheet(Excel excel, String name) {
  final defaultName = excel.getDefaultSheet();
  if (defaultName != null && defaultName != name) {
    excel.rename(defaultName, name);
  }
  return excel[name];
}

void _writeHeaderRow(Sheet sheet, List<String> headers) {
  final rowIndex = sheet.maxRows;
  for (var c = 0; c < headers.length; c++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
    cell.value = TextCellValue(headers[c]);
    cell.cellStyle = _headerStyle;
  }
}

void _appendMoneyRow(Sheet sheet, String label, double value, {bool bold = false}) {
  final row = <CellValue?>[TextCellValue(label), DoubleCellValue(value)];
  sheet.appendRow(row);
  if (bold) {
    final r = sheet.maxRows - 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = _boldStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = _boldStyle;
  }
}

/// Bangun file Excel ringkasan satu periode: sheet Laba Rugi (breakdown
/// Pendapatan/HPP/Beban Operasional lengkap per kategori, mengikuti struktur
/// laporan asli), Neraca Saldo, Rasio Keuangan, dan Analisa Singkat.
Uint8List buildRingkasanExcel(Period p) {
  final excel = Excel.createExcel();

  final labaRugi = _freshSheet(excel, 'Laba Rugi');
  labaRugi.setColumnWidth(0, 30);
  labaRugi.setColumnWidth(1, 18);
  _writeHeaderRow(labaRugi, ['${p.label} - PENDAPATAN', 'Rupiah']);
  for (final r in buildPendapatanList(p)) {
    _appendMoneyRow(labaRugi, r.label, r.value);
  }
  _appendMoneyRow(labaRugi, 'Total Pendapatan', p.totalPenjualan, bold: true);

  labaRugi.appendRow([]);
  _writeHeaderRow(labaRugi, ['HARGA POKOK PENJUALAN (HPP)', 'Rupiah']);
  _appendMoneyRow(labaRugi, 'Persediaan Awal', p.saldoAwal);
  _appendMoneyRow(labaRugi, 'Pembelian Bahan Baku', p.totalPembelianBahanBaku);
  _appendMoneyRow(labaRugi, 'Persediaan Akhir', -p.persediaanAkhir);
  _appendMoneyRow(labaRugi, 'Total HPP', p.hpp, bold: true);
  _appendMoneyRow(labaRugi, 'Laba Kotor', p.labaKotor, bold: true);

  labaRugi.appendRow([]);
  _writeHeaderRow(labaRugi, ['BEBAN OPERASIONAL', 'Rupiah']);
  for (final b in buildBebanList(p)) {
    _appendMoneyRow(labaRugi, b.label, b.value);
  }
  _appendMoneyRow(labaRugi, 'Total Beban Operasional', p.totalBeban, bold: true);
  _appendMoneyRow(labaRugi, 'Laba Bersih', p.labaBersih, bold: true);

  final neraca = excel['Neraca Saldo'];
  neraca.setColumnWidth(0, 30);
  neraca.setColumnWidth(1, 18);
  neraca.setColumnWidth(2, 18);
  _writeHeaderRow(neraca, ['Akun', 'Debit (Rp)', 'Kredit (Rp)']);
  var totalDebit = 0.0;
  var totalKredit = 0.0;
  for (final row in buildNeracaSaldoList(p)) {
    neraca.appendRow([
      TextCellValue(row.akun),
      DoubleCellValue(row.debit),
      DoubleCellValue(row.kredit),
    ]);
    totalDebit += row.debit;
    totalKredit += row.kredit;
  }
  final totalRowIndex = neraca.maxRows;
  neraca.appendRow([
    TextCellValue('Total'),
    DoubleCellValue(totalDebit),
    DoubleCellValue(totalKredit),
  ]);
  for (var c = 0; c < 3; c++) {
    neraca.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIndex)).cellStyle =
        _boldStyle;
  }

  final rasio = excel['Rasio Keuangan'];
  rasio.setColumnWidth(0, 26);
  rasio.setColumnWidth(1, 14);
  rasio.setColumnWidth(2, 22);
  _writeHeaderRow(rasio, ['Rasio', 'Hasil', 'Standar Ideal F&B']);
  for (final r in buildRasioList(p)) {
    rasio.appendRow([
      TextCellValue(r.nama),
      TextCellValue(formatPercent(r.hasil)),
      TextCellValue(r.standarIdeal),
    ]);
  }

  final analisa = excel['Analisa Singkat'];
  analisa.setColumnWidth(0, 100);
  final poinList = buildAnalisaSingkat(p);
  for (var i = 0; i < poinList.length; i++) {
    final poin = poinList[i];
    final judulRow = analisa.maxRows;
    analisa.appendRow([TextCellValue('${i + 1}. ${poin.judul}')]);
    analisa.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: judulRow)).cellStyle =
        _boldStyle;
    analisa.appendRow([TextCellValue(poin.isi)]);
    analisa.appendRow([]);
  }

  return Uint8List.fromList(excel.encode()!);
}
