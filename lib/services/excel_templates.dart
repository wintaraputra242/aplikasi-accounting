import 'dart:typed_data';

import 'package:excel/excel.dart';

final _headerStyle = CellStyle(
  bold: true,
  fontColorHex: ExcelColor.white,
  backgroundColorHex: ExcelColor.fromHexString('#00796B'),
  horizontalAlign: HorizontalAlign.Center,
  verticalAlign: VerticalAlign.Center,
);

final _noteStyle = CellStyle(
  italic: true,
  fontColorHex: ExcelColor.fromHexString('#757575'),
);

void _writeHeader(Sheet sheet, List<String> headers) {
  for (var c = 0; c < headers.length; c++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
    cell.value = TextCellValue(headers[c]);
    cell.cellStyle = _headerStyle;
  }
}

Sheet _freshSheet(Excel excel, String name) {
  final defaultName = excel.getDefaultSheet();
  if (defaultName != null && defaultName != name) {
    excel.rename(defaultName, name);
  }
  return excel[name];
}

/// Bangun file Excel template untuk upload data Penjualan: kolom
/// Kategori, Nominal saja (tanpa Tanggal), lengkap dengan contoh baris
/// memakai istilah kategori yang sudah biasa dipakai (Income Cash/QRIS
/// Mandiri/EDC On Us/dst) dan sheet "Petunjuk" berisi daftar kategori yang
/// dikenali sistem.
Uint8List buildPenjualanTemplate() {
  final excel = Excel.createExcel();
  final sheet = _freshSheet(excel, 'Penjualan');

  _writeHeader(sheet, ['Kategori', 'Nominal']);
  sheet.setColumnWidth(0, 22);
  sheet.setColumnWidth(1, 16);

  final contoh = <List<CellValue?>>[
    [TextCellValue('Income Cash'), IntCellValue(500000)],
    [TextCellValue('Income Qris Mandiri'), IntCellValue(750000)],
    [TextCellValue('Income EDC On Us'), IntCellValue(300000)],
    [TextCellValue('Income EDC Off Us'), IntCellValue(150000)],
    [TextCellValue('Income Gofood'), IntCellValue(200000)],
    [TextCellValue('Income Grabfood'), IntCellValue(150000)],
    [TextCellValue('Income Qris ESB'), IntCellValue(100000)],
    [TextCellValue('Income Other'), IntCellValue(50000)],
    [TextCellValue('Pendapatan Bunga'), IntCellValue(25000)],
  ];
  for (final row in contoh) {
    sheet.appendRow(row);
  }

  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([
    TextCellValue(
      'Baris di atas cuma contoh - hapus/timpa lalu isi data asli. '
      'Boleh tambah baris sebanyak apapun, sistem akan menjumlahkan '
      'otomatis per kategori.',
    ),
  ]);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle =
      _noteStyle;

  final petunjuk = excel['Petunjuk'];
  petunjuk.appendRow([TextCellValue('Kategori Penjualan yang Dikenali Sistem')]);
  petunjuk.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
      CellStyle(bold: true, fontSize: 14);
  petunjuk.appendRow([]);
  const daftarKategori = [
    ['Cash', 'Income Cash, Cash, Tunai'],
    ['QRIS Mandiri', 'Income Qris Mandiri, Income QR, Income QRIS, QRIS (tanpa kata ESB)'],
    ['EDC On Us', 'Income EDC On Us, EDC On-Us, On Us'],
    ['EDC Off Us', 'Income EDC Off Us, EDC Off-Us, Off Us'],
    ['GoFood', 'Income Gofood, GoFood, Go Food'],
    ['GrabFood', 'Income Grabfood, GrabFood, Grab'],
    ['QRIS ESB', 'Income Qris ESB, QRIS ESB, ESB'],
    ['Income Other', 'Income Other, Other, Lain-lain'],
    ['Pendapatan Bunga', 'Pendapatan Bunga, Bunga Bank, Bunga'],
  ];
  petunjuk.appendRow([TextCellValue('Kategori Sistem'), TextCellValue('Contoh Penulisan yang Dikenali')]);
  petunjuk.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = _headerStyle;
  petunjuk.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).cellStyle = _headerStyle;
  for (final row in daftarKategori) {
    petunjuk.appendRow([TextCellValue(row[0]), TextCellValue(row[1])]);
  }
  petunjuk.setColumnWidth(0, 18);
  petunjuk.setColumnWidth(1, 55);

  return Uint8List.fromList(excel.encode()!);
}

/// Bangun file Excel template untuk upload data Pembelian bahan baku:
/// kolom Tanggal, Nama Bahan Baku, Nominal.
Uint8List buildPembelianTemplate() {
  final excel = Excel.createExcel();
  final sheet = _freshSheet(excel, 'Pembelian');

  _writeHeader(sheet, ['Tanggal', 'Nama Bahan Baku', 'Nominal']);
  sheet.setColumnWidth(0, 14);
  sheet.setColumnWidth(1, 24);
  sheet.setColumnWidth(2, 16);

  final contoh = <List<CellValue?>>[
    [TextCellValue('2026-06-26'), TextCellValue('Beras'), IntCellValue(1200000)],
    [TextCellValue('2026-06-27'), TextCellValue('Ayam'), IntCellValue(2500000)],
    [TextCellValue('2026-06-28'), TextCellValue('Sayuran'), IntCellValue(800000)],
  ];
  for (final row in contoh) {
    sheet.appendRow(row);
  }

  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([
    TextCellValue(
      'Baris di atas cuma contoh - hapus/timpa lalu isi data asli. Boleh '
      'tambah baris sebanyak apapun (per item/per hari), sistem akan '
      'menjumlahkan semua nominal menjadi total pembelian bahan baku. '
      'Kolom Tanggal & Nama Bahan Baku boleh dikosongkan, yang penting '
      'kolom Nominal terisi.',
    ),
  ]);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle =
      _noteStyle;

  return Uint8List.fromList(excel.encode()!);
}
