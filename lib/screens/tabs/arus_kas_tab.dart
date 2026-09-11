import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/database_helper.dart';
import '../../models/arus_kas.dart';
import '../../models/fixed_asset.dart';
import '../../models/period.dart';
import '../../state/period_editor.dart';
import '../../widgets/report_widgets.dart';

/// Tab Arus Kas: laporan tidak langsung (indirect method), dihitung dari
/// Laba Bersih periode ini + perubahan saldo akun Neraca dibanding periode
/// sebelumnya (lihat `lib/models/arus_kas.dart`). Tidak ada input di tab
/// ini -- semua datanya sudah diisi lewat tab Penjualan/Pembelian/Beban/Aset/
/// Neraca.
class ArusKasTab extends StatefulWidget {
  const ArusKasTab({super.key});

  @override
  State<ArusKasTab> createState() => _ArusKasTabState();
}

class _ArusKasTabState extends State<ArusKasTab> {
  List<Period> _allPeriods = [];
  List<FixedAssetItem> _fixedAssets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseHelper.instance.getAllPeriods(),
      DatabaseHelper.instance.getAllFixedAssets(),
    ]);
    if (!mounted) return;
    setState(() {
      _allPeriods = results[0] as List<Period>;
      _fixedAssets = results[1] as List<FixedAssetItem>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PeriodEditor>();
    final p = editor.period;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final previous = findPreviousPeriod(_allPeriods, p);
    final data = buildArusKas(current: p, previous: previous, fixedAssets: _fixedAssets);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (previous == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Belum ada periode sebelumnya -- Saldo Kas Awal diasumsikan Rp0. '
              'Buat/isi periode-periode sebelumnya supaya Arus Kas akurat.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ArusKasCard(data: data),
      ],
    );
  }
}
