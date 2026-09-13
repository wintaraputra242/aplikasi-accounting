import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/journal.dart';
import '../services/journal_service.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/quick_nav.dart';

final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

/// Layar Buku Besar (General Ledger): daftar akun (dari [kChartOfAccounts])
/// yang punya transaksi, tap untuk buka kartu akun -- list transaksi
/// kronologis + saldo berjalan.
class BukuBesarScreen extends StatefulWidget {
  const BukuBesarScreen({super.key});

  @override
  State<BukuBesarScreen> createState() => _BukuBesarScreenState();
}

class _BukuBesarScreenState extends State<BukuBesarScreen> {
  late Future<List<String>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = JournalService.instance.getAccountsWithTransactions();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Cocokkan pencarian ke kode akun ATAU nama akun -- supaya pengguna bisa
  /// cari pakai salah satu, mis. "kas" atau "10.1".
  List<String> _filter(List<String> kodes) {
    if (_query.isEmpty) return kodes;
    return kodes.where((kode) {
      final nama = findAccount(kode)?.nama.toLowerCase() ?? '';
      return kode.toLowerCase().contains(_query) || nama.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const GlAppBarTitle('Buku Besar'),
        actions: const [QuickNavButton(current: QuickNavTarget.bukuBesar)],
      ),
      body: FutureBuilder<List<String>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final kodes = snapshot.data ?? [];
          if (kodes.isEmpty) {
            return const Center(
              child: Text('Belum ada transaksi. Catat lewat menu Transaksi Kas dulu.'),
            );
          }
          final filtered = _filter(kodes);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari akun (nama atau kode)...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Tidak ada akun yang cocok.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final account = findAccount(filtered[i]);
                          final nama = account?.nama ?? filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              title: Text(nama),
                              subtitle: Text(
                                  '${filtered[i]}${account != null ? ' • ${account.kategori}' : ''}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _BukuBesarDetailScreen(
                                      akunKode: filtered[i], akunNama: nama),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BukuBesarDetailScreen extends StatefulWidget {
  final String akunKode;
  final String akunNama;

  const _BukuBesarDetailScreen({required this.akunKode, required this.akunNama});

  @override
  State<_BukuBesarDetailScreen> createState() => _BukuBesarDetailScreenState();
}

class _BukuBesarDetailScreenState extends State<_BukuBesarDetailScreen> {
  late Future<List<LedgerRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = JournalService.instance.getLedgerForAccount(widget.akunKode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.akunNama),
      ),
      body: FutureBuilder<List<LedgerRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No. Rek: ${widget.akunKode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.akunNama, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Belum ada transaksi di akun ini.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('Keterangan')),
                            DataColumn(label: Text('Sumber')),
                            DataColumn(label: Text('Debit'), numeric: true),
                            DataColumn(label: Text('Kredit'), numeric: true),
                            DataColumn(label: Text('Saldo'), numeric: true),
                          ],
                          rows: rows.map((r) {
                            final keterangan = [
                              if (r.pihak.isNotEmpty) r.pihak,
                              if (r.keterangan.isNotEmpty) r.keterangan,
                            ].join(' - ');
                            return DataRow(cells: [
                              DataCell(Text(_dateFmt.format(r.tanggal))),
                              DataCell(Text(keterangan.isEmpty ? '-' : keterangan)),
                              DataCell(Text(r.sumber)),
                              DataCell(Text(r.debit > 0 ? formatRupiah(r.debit) : '')),
                              DataCell(Text(r.kredit > 0 ? formatRupiah(r.kredit) : '')),
                              DataCell(Text(
                                formatRupiah(r.saldoBerjalan),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
