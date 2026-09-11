import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/period.dart';
import '../state/period_editor.dart';
import '../state/stock_editor.dart';
import 'tabs/aset_tab.dart';
import 'tabs/arus_kas_tab.dart';
import 'tabs/beban_tab.dart';
import 'tabs/neraca_saldo_tab.dart';
import 'tabs/neraca_tab.dart';
import 'tabs/pajak_tab.dart';
import 'tabs/pembelian_tab.dart';
import 'tabs/penjualan_tab.dart';
import 'tabs/ringkasan_tab.dart';
import 'tabs/stock_tab.dart';

/// Layar detail satu periode, berisi 10 tab: Penjualan, Pembelian, Stock,
/// Aset, Beban, Neraca Saldo, Neraca (Posisi Keuangan), Pajak (Tax Control),
/// Arus Kas, dan Ringkasan (laba & rasio keuangan). Semua perubahan otomatis
/// tersimpan ke
/// database lokal lewat [PeriodEditor] (Stock tersimpan langsung tiap
/// perubahan lewat [StockEditor]; Fixed Asset Register tersimpan lewat CRUD
/// langsung ke database, lihat `fixed_asset_register_screen.dart`).
class PeriodDetailScreen extends StatefulWidget {
  final int periodId;

  const PeriodDetailScreen({super.key, required this.periodId});

  @override
  State<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends State<PeriodDetailScreen> {
  Period? _period;
  // Dicek di PopScope supaya periode yang baru dihapus tidak ter-simpan lagi
  // oleh autosave saat layar ini ditutup.
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final period = await DatabaseHelper.instance.getPeriodById(widget.periodId);
    if (mounted) setState(() => _period = period);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus periode ini?'),
        content: const Text('Semua data pada periode ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deletePeriod(widget.periodId);
    _deleted = true;
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    if (period == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PeriodEditor(period)),
        ChangeNotifierProvider(create: (_) => StockEditor(period.id!)),
      ],
      child: Consumer<PeriodEditor>(
        builder: (context, editor, _) {
          return PopScope(
            // Tunda pop sampai simpanan terakhir benar-benar selesai ditulis
            // ke database, supaya daftar periode di halaman utama tidak
            // sempat me-refresh dengan data yang belum tersimpan (race
            // condition antara "back" dan autosave yang sedang di-debounce).
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              if (!_deleted) await editor.saveNow();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: DefaultTabController(
              length: 10,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(editor.period.label),
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(icon: Icon(Icons.point_of_sale), text: 'Penjualan'),
                      Tab(icon: Icon(Icons.shopping_cart), text: 'Pembelian'),
                      Tab(icon: Icon(Icons.inventory_2), text: 'Stock'),
                      Tab(icon: Icon(Icons.inventory), text: 'Aset'),
                      Tab(icon: Icon(Icons.receipt_long), text: 'Beban'),
                      Tab(icon: Icon(Icons.balance), text: 'Neraca Saldo'),
                      Tab(icon: Icon(Icons.account_balance_wallet), text: 'Neraca'),
                      Tab(icon: Icon(Icons.percent), text: 'Pajak'),
                      Tab(icon: Icon(Icons.swap_vert), text: 'Arus Kas'),
                      Tab(icon: Icon(Icons.summarize), text: 'Ringkasan'),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (editor.isSaving) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Menyimpan...',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ] else ...[
                            const Icon(Icons.cloud_done, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Tersimpan',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Hapus periode',
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
                body: const TabBarView(
                  children: [
                    PenjualanTab(),
                    PembelianTab(),
                    StockTab(),
                    AsetTab(),
                    BebanTab(),
                    NeracaSaldoTab(),
                    NeracaTab(),
                    PajakTab(),
                    ArusKasTab(),
                    RingkasanTab(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
