import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/database_helper.dart';
import '../../models/business_profile.dart';
import '../../models/fixed_asset.dart';
import '../../models/period.dart';
import '../../models/posisi_keuangan.dart';
import '../../state/period_editor.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/report_widgets.dart';

/// Tab Neraca: input saldo akhir akun Kas/Bank, Piutang, Hutang, dan Modal &
/// Prive periode ini, ditutup dengan laporan Posisi Keuangan yang dirakit
/// dari input-input ini plus Fixed Asset Register dan histori periode lain
/// (lihat `lib/models/posisi_keuangan.dart`).
class NeracaTab extends StatefulWidget {
  const NeracaTab({super.key});

  @override
  State<NeracaTab> createState() => _NeracaTabState();
}

class _NeracaTabState extends State<NeracaTab> {
  List<Period> _allPeriods = [];
  List<FixedAssetItem> _fixedAssets = [];
  BusinessProfile _profile = const BusinessProfile();
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
      DatabaseHelper.instance.getBusinessProfile(),
    ]);
    if (!mounted) return;
    setState(() {
      _allPeriods = results[0] as List<Period>;
      _fixedAssets = results[1] as List<FixedAssetItem>;
      _profile = results[2] as BusinessProfile;
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

    final data = buildPosisiKeuangan(
      current: p,
      allPeriods: _allPeriods,
      fixedAssets: _fixedAssets,
      profile: _profile,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Kas & Bank (Saldo Akhir Periode)',
          icon: Icons.account_balance_wallet,
          child: CustomAccountsSection(
            items: p.kasBankItems,
            onItemChanged: editor.updateKasBankItem,
            onItemRemoved: editor.removeKasBankItem,
            onAddItem: () => showAddAccountDialog(
              context,
              title: 'Tambah Akun Kas/Bank',
              onAdd: editor.addKasBankItem,
            ),
          ),
        ),
        SectionCard(
          title: 'Aset Lancar Lainnya',
          icon: Icons.inventory_2,
          child: Column(
            children: [
              MoneyField(
                label: 'Piutang Usaha',
                value: p.piutangUsaha,
                icon: Icons.request_page,
                onChanged: editor.setPiutangUsaha,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Beban Dibayar Dimuka (Prepaid)',
                value: p.bebanDibayarDimuka,
                icon: Icons.schedule,
                onChanged: editor.setBebanDibayarDimuka,
              ),
              const SizedBox(height: 10),
              MoneyDisplayRow(
                label: 'Persediaan Akhir (diisi di tab Pembelian)',
                value: p.persediaanAkhir,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Akun Tambahan Aset Lancar',
          icon: Icons.playlist_add,
          child: CustomAccountsSection(
            items: p.customCurrentAssetItems,
            onItemChanged: editor.updateCustomCurrentAssetItem,
            onItemRemoved: editor.removeCustomCurrentAssetItem,
            onAddItem: () => showAddAccountDialog(
              context,
              title: 'Tambah Akun Aset Lancar',
              onAdd: editor.addCustomCurrentAssetItem,
            ),
          ),
        ),
        SectionCard(
          title: 'Hutang / Liabilitas',
          icon: Icons.request_quote,
          child: Column(
            children: [
              MoneyField(
                label: 'Hutang Usaha (Supplier)',
                value: p.hutangUsaha,
                icon: Icons.local_shipping,
                onChanged: editor.setHutangUsaha,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang Gaji Karyawan',
                value: p.hutangGajiKaryawan,
                icon: Icons.people,
                onChanged: editor.setHutangGajiKaryawan,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang PB1',
                value: p.hutangPb1,
                icon: Icons.receipt,
                onChanged: editor.setHutangPb1,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang PPh 21',
                value: p.hutangPph21,
                icon: Icons.receipt,
                onChanged: editor.setHutangPph21,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang PPh 23',
                value: p.hutangPph23,
                icon: Icons.receipt,
                onChanged: editor.setHutangPph23,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang Pajak Badan',
                value: p.hutangPajakBadan,
                icon: Icons.receipt_long,
                onChanged: editor.setHutangPajakBadan,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang Service Charge',
                value: p.hutangServiceCharge,
                icon: Icons.room_service,
                onChanged: editor.setHutangServiceCharge,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Hutang Lain-lain',
                value: p.hutangLainLain,
                icon: Icons.more_horiz,
                onChanged: editor.setHutangLainLain,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Pendapatan Diterima Dimuka',
                value: p.pendapatanDiterimaDimuka,
                icon: Icons.event_available,
                onChanged: editor.setPendapatanDiterimaDimuka,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Pinjaman (Loan Payable)',
                value: p.pinjaman,
                icon: Icons.account_balance,
                onChanged: editor.setPinjaman,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Akun Hutang Tambahan',
          icon: Icons.playlist_add,
          child: CustomAccountsSection(
            items: p.customLiabilityItems,
            onItemChanged: editor.updateCustomLiabilityItem,
            onItemRemoved: editor.removeCustomLiabilityItem,
            onAddItem: () => showAddAccountDialog(
              context,
              title: 'Tambah Akun Hutang',
              onAdd: editor.addCustomLiabilityItem,
            ),
          ),
        ),
        SectionCard(
          title: 'Modal & Prive (Periode Ini)',
          icon: Icons.savings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modal Awal Usaha (nilai tetap, sekali diisi, sebelum aplikasi '
                'ini mulai dipakai) diisi lewat menu titik tiga > Profil Usaha.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Setoran Modal Periode Ini',
                value: p.modalDisetorPeriodeIni,
                icon: Icons.add_card,
                onChanged: editor.setModalDisetorPeriodeIni,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Prive / Pengambilan Owner Periode Ini',
                value: p.privePeriodeIni,
                icon: Icons.money_off,
                onChanged: editor.setPrivePeriodeIni,
              ),
            ],
          ),
        ),
        PosisiKeuanganCard(data: data),
      ],
    );
  }
}
