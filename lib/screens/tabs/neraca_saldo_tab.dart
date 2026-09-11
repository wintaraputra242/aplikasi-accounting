import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/period_editor.dart';
import '../../widgets/report_widgets.dart';

/// Tab Neraca Saldo: daftar akun debit/kredit yang diturunkan dari data
/// Penjualan, Pembelian, dan Beban -- lihat [NeracaSaldoCard] &
/// `buildNeracaSaldoList` untuk penjelasan pendekatan penyeimbangannya.
class NeracaSaldoTab extends StatelessWidget {
  const NeracaSaldoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PeriodEditor>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        NeracaSaldoCard(period: editor.period),
      ],
    );
  }
}
