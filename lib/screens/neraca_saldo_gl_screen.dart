import 'package:flutter/material.dart';

import '../models/journal.dart';
import '../services/journal_service.dart';
import '../utils/formatters.dart';
import '../widgets/quick_nav.dart';

/// Layar Neraca Saldo (dari GL): daftar SEMUA akun dari Buku Besar dengan
/// saldo debit/kredit, baris total (harus selalu balance karena tiap
/// posting jurnal sudah seimbang). Ini TERPISAH dari tab "Neraca Saldo" lama
/// (neraca_saldo_tab.dart) yang tetap berjalan berbasis input P&L manual --
/// lihat blueprint_revisi_mangana.txt Bagian 2.
class NeracaSaldoGlScreen extends StatefulWidget {
  const NeracaSaldoGlScreen({super.key});

  @override
  State<NeracaSaldoGlScreen> createState() => _NeracaSaldoGlScreenState();
}

class _NeracaSaldoGlScreenState extends State<NeracaSaldoGlScreen> {
  late Future<List<TrialBalanceRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = JournalService.instance.getTrialBalanceFromGl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neraca Saldo (GL)'),
        actions: const [QuickNavButton(current: QuickNavTarget.neracaSaldoGl)],
      ),
      body: FutureBuilder<List<TrialBalanceRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Text('Belum ada transaksi. Catat lewat menu Transaksi Kas dulu.'),
            );
          }
          final totalDebit = rows.fold<double>(0, (s, r) => s + r.debit);
          final totalKredit = rows.fold<double>(0, (s, r) => s + r.kredit);
          final balanced = (totalDebit - totalKredit).abs() < 1;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Kode')),
                      DataColumn(label: Text('Nama Akun')),
                      DataColumn(label: Text('Debit'), numeric: true),
                      DataColumn(label: Text('Kredit'), numeric: true),
                    ],
                    rows: [
                      ...rows.map((r) => DataRow(cells: [
                            DataCell(Text(r.akunKode)),
                            DataCell(Text(r.akunNama)),
                            DataCell(Text(r.debit > 0 ? formatRupiah(r.debit) : '')),
                            DataCell(Text(r.kredit > 0 ? formatRupiah(r.kredit) : '')),
                          ])),
                      DataRow(cells: [
                        const DataCell(Text('')),
                        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatRupiah(totalDebit), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatRupiah(totalKredit), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: balanced ? Colors.green.shade50 : Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(
                      balanced ? Icons.check_circle : Icons.error,
                      color: balanced ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        balanced
                            ? 'Balance (Debit = Kredit)'
                            : 'TIDAK balance -- selisih ${formatRupiah((totalDebit - totalKredit).abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balanced ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
