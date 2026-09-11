import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../db/database_helper.dart';
import '../../models/business_profile.dart';
import '../../state/period_editor.dart';
import '../../widgets/common_widgets.dart';

final _tanggalFormat = DateFormat('d MMM yyyy', 'id_ID');

/// Tab Pajak (Tax Control): Tax Base, Tax Rate, Tax Payable dihitung
/// otomatis dari Total Penjualan periode ini (lihat getter di
/// `lib/models/period.dart`); Tax Paid & Tax Fund diisi manual. Tarif pajak
/// diatur sekali di Profil Usaha (menu titik tiga), bukan di sini.
///
/// Cakupan saat ini: PBJT/PB1 (default 10%) dan PPh Final UMKM (default
/// 0.5% dari omset). Jenis pajak lain (PPh 21, PPh 23, Pajak Badan) belum
/// direkonsiliasi otomatis di sini -- hutangnya tetap diisi manual di tab
/// Neraca seperti sebelumnya.
class PajakTab extends StatefulWidget {
  const PajakTab({super.key});

  @override
  State<PajakTab> createState() => _PajakTabState();
}

class _PajakTabState extends State<PajakTab> {
  BusinessProfile _profile = const BusinessProfile();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final editor = context.watch<PeriodEditor>();
    final p = editor.period;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _TaxCard(
          title: 'PBJT / PB1',
          icon: Icons.receipt_long,
          ratePersen: _profile.pbjtTaxRatePersen,
          payable: p.pbjtTaxPayable(_profile.pbjtTaxRatePersen),
          paid: p.pbjtTaxPaid,
          fund: p.pbjtTaxFund,
          dueDate: p.pbjtDueDate,
          onPaidChanged: editor.setPbjtTaxPaid,
          onFundChanged: editor.setPbjtTaxFund,
        ),
        _TaxCard(
          title: 'PPh Final UMKM',
          icon: Icons.receipt_long,
          ratePersen: _profile.pphFinalTaxRatePersen,
          payable: p.pphFinalTaxPayable(_profile.pphFinalTaxRatePersen),
          paid: p.pphFinalTaxPaid,
          fund: p.pphFinalTaxFund,
          dueDate: p.pphFinalDueDate,
          onPaidChanged: editor.setPphFinalTaxPaid,
          onFundChanged: editor.setPphFinalTaxFund,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tarif pajak diatur sekali di menu titik tiga > Profil Usaha. '
            'PPh 21, PPh 23, dan Pajak Badan belum direkonsiliasi otomatis '
            'di sini -- tetap diisi manual di tab Neraca.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _TaxCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double ratePersen;
  final double payable;
  final double paid;
  final double fund;
  final DateTime dueDate;
  final ValueChanged<double> onPaidChanged;
  final ValueChanged<double> onFundChanged;

  const _TaxCard({
    required this.title,
    required this.icon,
    required this.ratePersen,
    required this.payable,
    required this.paid,
    required this.fund,
    required this.dueDate,
    required this.onPaidChanged,
    required this.onFundChanged,
  });

  @override
  Widget build(BuildContext context) {
    final outstanding = payable - paid;
    final outstandingColor = outstanding > 0
        ? Colors.orange.shade800
        : (outstanding < 0 ? Colors.red : Colors.green.shade700);

    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tax Rate', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  '${ratePersen.toStringAsFixed(ratePersen == ratePersen.roundToDouble() ? 0 : 2)}% dari Total Penjualan',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(),
          MoneyDisplayRow(label: 'Tax Payable', value: payable, bold: true),
          const SizedBox(height: 10),
          MoneyField(label: 'Tax Paid (Sudah Dibayar)', value: paid, onChanged: onPaidChanged),
          const SizedBox(height: 10),
          MoneyDisplayRow(label: 'Outstanding', value: outstanding, color: outstandingColor),
          const Divider(),
          MoneyField(
            label: 'Tax Fund (Dana Disisihkan)',
            value: fund,
            icon: Icons.savings,
            onChanged: onFundChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'Jatuh tempo: ${_tanggalFormat.format(dueDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
