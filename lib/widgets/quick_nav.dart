import 'package:flutter/material.dart';

import '../screens/buku_besar_screen.dart';
import '../screens/fixed_asset_register_screen.dart';
import '../screens/invoice_form_screen.dart';
import '../screens/invoice_history_screen.dart';
import '../screens/jurnal_penyesuaian_screen.dart';
import '../screens/kas_transaksi_screen.dart';
import '../screens/master_barang_screen.dart';
import '../screens/neraca_saldo_gl_screen.dart';
import '../screens/rekonsiliasi_bank_screen.dart';
import '../screens/ringkasan_tahunan_screen.dart';

/// Modul-modul yang bisa dituju lewat [QuickNavButton] -- dipakai untuk tandai
/// "lagi di layar mana" supaya menu tidak menampilkan tujuan yang sama dengan
/// layar yang sedang dibuka.
enum QuickNavTarget {
  transaksiKas,
  bukuBesar,
  neracaSaldoGl,
  jurnalPenyesuaian,
  rekonsiliasiBank,
  fixedAssetRegister,
  masterBarang,
  riwayatInvoice,
  buatInvoice,
  ringkasanTahunan,
}

class _QuickNavItem {
  final QuickNavTarget target;
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  const _QuickNavItem(this.target, this.icon, this.label, this.builder);
}

final _kQuickNavItems = <_QuickNavItem>[
  _QuickNavItem(QuickNavTarget.transaksiKas, Icons.payments_outlined, 'Transaksi Kas',
      (_) => const KasTransaksiScreen()),
  _QuickNavItem(QuickNavTarget.bukuBesar, Icons.menu_book_outlined, 'Buku Besar',
      (_) => const BukuBesarScreen()),
  _QuickNavItem(QuickNavTarget.neracaSaldoGl, Icons.balance_outlined, 'Neraca Saldo (GL)',
      (_) => const NeracaSaldoGlScreen()),
  _QuickNavItem(QuickNavTarget.jurnalPenyesuaian, Icons.tune, 'Jurnal Penyesuaian',
      (_) => const JurnalPenyesuaianScreen()),
  _QuickNavItem(QuickNavTarget.rekonsiliasiBank, Icons.account_balance_outlined, 'Rekonsiliasi Bank',
      (_) => const RekonsiliasiBankScreen()),
  _QuickNavItem(QuickNavTarget.fixedAssetRegister, Icons.inventory, 'Fixed Asset Register',
      (_) => const FixedAssetRegisterScreen()),
  _QuickNavItem(QuickNavTarget.masterBarang, Icons.inventory_2_outlined, 'Master Barang',
      (_) => const MasterBarangScreen()),
  _QuickNavItem(QuickNavTarget.riwayatInvoice, Icons.history, 'Riwayat Invoice',
      (_) => const InvoiceHistoryScreen()),
  _QuickNavItem(QuickNavTarget.buatInvoice, Icons.request_quote_outlined, 'Buat Invoice',
      (_) => const InvoiceFormScreen()),
  _QuickNavItem(QuickNavTarget.ringkasanTahunan, Icons.calendar_view_month, 'Ringkasan Tahunan',
      (_) => const RingkasanTahunanScreen()),
];

/// Tombol pintasan di AppBar untuk lompat langsung ke modul lain (Transaksi
/// Kas <-> Buku Besar <-> Neraca Saldo GL <-> dst) TANPA harus back ke Home
/// dulu -- pasang di tiap layar modul dengan [current] diisi modul itu
/// sendiri supaya tidak muncul di daftar pilihannya sendiri.
///
/// Pakai [Navigator.pushReplacement] (bukan push biasa) supaya pindah modul
/// terasa seperti ganti tab -- tidak menumpuk banyak layar di back stack
/// kalau pengguna lompat-lompat antar modul berkali-kali. Tekan back dari
/// modul manapun akan langsung kembali ke Home.
class QuickNavButton extends StatelessWidget {
  final QuickNavTarget current;
  const QuickNavButton({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final items = _kQuickNavItems.where((i) => i.target != current).toList();
    return PopupMenuButton<_QuickNavItem>(
      icon: const Icon(Icons.swap_horiz),
      tooltip: 'Pindah ke Menu Lain',
      onSelected: (item) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: item.builder),
        );
      },
      itemBuilder: (context) => items
          .map((i) => PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Icon(i.icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(i.label),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
