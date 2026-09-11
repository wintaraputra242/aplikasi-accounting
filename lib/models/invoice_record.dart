import 'dart:convert';

import 'invoice.dart';

/// Invoice yang sudah pernah digenerate & disimpan ke database, supaya bisa
/// dilihat lagi di halaman Riwayat Invoice, diedit, atau di-download ulang
/// PDF-nya tanpa perlu mengetik ulang semua data.
class InvoiceRecord {
  final int? id;
  final String noInvoice;
  final DateTime tanggalInvoice;
  final DateTime jatuhTempo;
  final String namaPenerima;
  final String alamatPenerima;
  final List<InvoiceItem> items;
  final DateTime createdAt;

  const InvoiceRecord({
    this.id,
    required this.noInvoice,
    required this.tanggalInvoice,
    required this.jatuhTempo,
    required this.namaPenerima,
    required this.alamatPenerima,
    required this.items,
    required this.createdAt,
  });

  double get totalTagihan => items.fold(0, (a, item) => a + item.total);

  InvoiceData toInvoiceData() => InvoiceData(
        noInvoice: noInvoice,
        tanggalInvoice: tanggalInvoice,
        jatuhTempo: jatuhTempo,
        namaPenerima: namaPenerima,
        alamatPenerima: alamatPenerima,
        items: items,
      );

  InvoiceRecord copyWith({
    int? id,
    String? noInvoice,
    DateTime? tanggalInvoice,
    DateTime? jatuhTempo,
    String? namaPenerima,
    String? alamatPenerima,
    List<InvoiceItem>? items,
    DateTime? createdAt,
  }) {
    return InvoiceRecord(
      id: id ?? this.id,
      noInvoice: noInvoice ?? this.noInvoice,
      tanggalInvoice: tanggalInvoice ?? this.tanggalInvoice,
      jatuhTempo: jatuhTempo ?? this.jatuhTempo,
      namaPenerima: namaPenerima ?? this.namaPenerima,
      alamatPenerima: alamatPenerima ?? this.alamatPenerima,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _dateToIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _dateFromIso(String s) {
    final parts = s.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'no_invoice': noInvoice,
      'tanggal_invoice': _dateToIso(tanggalInvoice),
      'jatuh_tempo': _dateToIso(jatuhTempo),
      'nama_penerima': namaPenerima,
      'alamat_penerima': alamatPenerima,
      'items_json': jsonEncode(items
          .map((i) => {
                'keterangan': i.keterangan,
                'jumlah': i.jumlah,
                'harga': i.harga,
              })
          .toList()),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InvoiceRecord.fromMap(Map<String, Object?> map) {
    final rawItems = jsonDecode(map['items_json'] as String) as List;
    return InvoiceRecord(
      id: map['id'] as int?,
      noInvoice: map['no_invoice'] as String,
      tanggalInvoice: _dateFromIso(map['tanggal_invoice'] as String),
      jatuhTempo: _dateFromIso(map['jatuh_tempo'] as String),
      namaPenerima: map['nama_penerima'] as String,
      alamatPenerima: (map['alamat_penerima'] as String?) ?? '',
      items: rawItems
          .map((e) => InvoiceItem(
                keterangan: e['keterangan'] as String,
                jumlah: e['jumlah'] as int,
                harga: (e['harga'] as num).toDouble(),
              ))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
