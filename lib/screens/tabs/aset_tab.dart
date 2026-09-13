import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/database_helper.dart';
import '../../models/fixed_asset.dart';
import '../../state/period_editor.dart';
import '../../widgets/common_widgets.dart';
import '../fixed_asset_register_screen.dart';

/// Tab Aset: checklist penutupan aset, rekap Beban Penyusutan periode ini
/// per kategori (dihitung otomatis dari Fixed Asset Register), dan tombol
/// sinkronisasi ke tab Beban.
class AsetTab extends StatefulWidget {
  const AsetTab({super.key});

  @override
  State<AsetTab> createState() => _AsetTabState();
}

const _checklistItems = [
  'Ada aset baru yang dibeli?',
  'Ada aset yang rusak?',
  'Ada aset yang dijual?',
  'Ada aset yang hilang?',
  'Ada aset yang sudah tidak digunakan?',
];

class _AsetTabState extends State<AsetTab> {
  List<FixedAssetItem> _assets = [];
  bool _loading = true;
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final assets = await DatabaseHelper.instance.getAllFixedAssets();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FixedAssetRegisterScreen()),
    );
    await _load();
  }

  /// Beban Penyusutan periode ini per kategori: satu bulan penuh untuk
  /// tiap aset yang aktif selama rentang tanggal periode (tanpa prorata
  /// harian) -- lihat [FixedAssetItem.aktifPadaPeriode].
  Map<String, double> _penyusutanPerKategori(PeriodEditor editor) {
    final period = editor.period;
    final totals = {for (final k in kKategoriAset) k: 0.0};
    for (final a in _assets) {
      if (a.aktifPadaPeriode(period.startDate, period.endDate)) {
        totals[a.kategori] = (totals[a.kategori] ?? 0) + a.penyusutanPerBulan;
      }
    }
    return totals;
  }

  Future<void> _sync(PeriodEditor editor) async {
    final totals = _penyusutanPerKategori(editor);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update ke Tab Beban?'),
        content: const Text(
          'Penyusutan Bar/Kitchen/Furniture Area/Office di tab Beban akan '
          'ditimpa dengan hasil perhitungan dari Fixed Asset Register untuk '
          'periode ini. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    if (confirm != true) return;

    editor.setBebanPenyusutanBar(totals['Bar'] ?? 0);
    editor.setBebanPenyusutanKitchen(totals['Kitchen'] ?? 0);
    editor.setBebanPenyusutanFurnitureArea(totals['Furniture Area'] ?? 0);
    editor.setBebanPenyusutanOffice(totals['Office'] ?? 0);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Beban Penyusutan tab Beban berhasil di-update.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PeriodEditor>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totals = _penyusutanPerKategori(editor);
    final totalPenyusutan = totals.values.fold(0.0, (a, b) => a + b);
    final asetAktifCount = _assets.where((a) => a.aktif).length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Checklist Penutupan Aset (tanggal 25)',
          icon: Icons.checklist,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pengingat visual saja (tidak tersimpan) -- centang sambil cek '
                'Fixed Asset Register sebelum tutup periode.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < _checklistItems.length; i++)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(_checklistItems[i]),
                  value: _checked.contains(i),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _checked.add(i);
                    } else {
                      _checked.remove(i);
                    }
                  }),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Fixed Asset Register',
          icon: Icons.inventory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$asetAktifCount aset aktif tercatat.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openRegister,
                icon: const Icon(Icons.list_alt),
                label: const Text('Kelola Daftar Aset'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Penyusutan Periode Ini per Kategori',
          icon: Icons.calculate,
          child: Column(
            children: [
              for (final k in kKategoriAset)
                MoneyDisplayRow(label: k, value: totals[k] ?? 0),
              const Divider(),
              MoneyDisplayRow(
                label: 'Total Penyusutan',
                value: totalPenyusutan,
                bold: true,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Sinkronkan ke Tab Beban',
          icon: Icons.sync,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tekan tombol ini setelah Fixed Asset Register di-update supaya '
                'field Penyusutan Bar/Kitchen/Furniture Area/Office di tab Beban '
                'terisi otomatis -- jadi angka penyusutan selalu bisa ditelusuri '
                'balik ke daftar aset ini.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _sync(editor),
                icon: const Icon(Icons.sync),
                label: const Text('Update ke Tab Beban'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
