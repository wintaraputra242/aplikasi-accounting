/// Satu baris item pada invoice yang mau di-generate. Dipakai sebagai state
/// form sementara di [InvoiceFormScreen] -- tidak disimpan ke database,
/// invoice cuma perlu digenerate jadi PDF lalu dibagikan/dikirim manual.
class InvoiceItem {
  String keterangan;
  int jumlah;
  double harga;

  InvoiceItem({this.keterangan = '', this.jumlah = 1, this.harga = 0});

  double get total => jumlah * harga;
}

/// Data lengkap satu invoice yang mau digenerate jadi PDF.
class InvoiceData {
  final String noInvoice;
  final DateTime tanggalInvoice;
  final DateTime jatuhTempo;
  final String namaPenerima;
  final String alamatPenerima;
  final List<InvoiceItem> items;

  const InvoiceData({
    required this.noInvoice,
    required this.tanggalInvoice,
    required this.jatuhTempo,
    required this.namaPenerima,
    required this.alamatPenerima,
    required this.items,
  });

  double get totalTagihan => items.fold(0, (a, item) => a + item.total);
}
