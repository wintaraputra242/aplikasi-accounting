import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/period_editor.dart';
import '../../widgets/common_widgets.dart';

/// Tab Beban: form input beban operasional bulanan.
class BebanTab extends StatelessWidget {
  const BebanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<PeriodEditor>();
    final p = editor.period;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          title: 'Beban Operasional',
          icon: Icons.receipt_long,
          child: Column(
            children: [
              MoneyField(
                label: 'Gaji Karyawan',
                value: p.bebanGajiKaryawan,
                icon: Icons.people,
                onChanged: editor.setBebanGajiKaryawan,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Listrik Bulanan',
                value: p.bebanListrikBulanan,
                icon: Icons.bolt,
                onChanged: editor.setBebanListrikBulanan,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Listrik (per 2 Minggu)',
                value: p.bebanListrikDuaMingguan,
                icon: Icons.electric_bolt,
                onChanged: editor.setBebanListrikDuaMingguan,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Pembayaran IPL',
                value: p.bebanIpl,
                icon: Icons.apartment,
                onChanged: editor.setBebanIpl,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Supplies & Cleaning',
                value: p.bebanSuppliesCleaning,
                icon: Icons.cleaning_services,
                onChanged: editor.setBebanSuppliesCleaning,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Waste/Susut Bahan Baku',
                value: p.bebanWasteBahanBaku,
                icon: Icons.delete_sweep,
                onChanged: editor.setBebanWasteBahanBaku,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'MDR QRIS',
                value: p.bebanMdrQris,
                icon: Icons.qr_code,
                onChanged: editor.setBebanMdrQris,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'MDR EDC',
                value: p.bebanMdrEdc,
                icon: Icons.credit_card,
                onChanged: editor.setBebanMdrEdc,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'MDR ESB',
                value: p.bebanMdrEsb,
                icon: Icons.account_balance,
                onChanged: editor.setBebanMdrEsb,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'MDR Go-Food',
                value: p.bebanMdrGofood,
                icon: Icons.delivery_dining,
                onChanged: editor.setBebanMdrGofood,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'MDR Grab-Food',
                value: p.bebanMdrGrabfood,
                icon: Icons.delivery_dining,
                onChanged: editor.setBebanMdrGrabfood,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Marketing',
                value: p.bebanMarketing,
                icon: Icons.campaign,
                onChanged: editor.setBebanMarketing,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Biaya Adm Transfer',
                value: p.bebanAdmTransfer,
                icon: Icons.swap_horiz,
                onChanged: editor.setBebanAdmTransfer,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Biaya Kartu Debit',
                value: p.bebanKartuDebit,
                icon: Icons.credit_card,
                onChanged: editor.setBebanKartuDebit,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Biaya Admin Rekening',
                value: p.bebanAdminRekening,
                icon: Icons.account_balance_wallet,
                onChanged: editor.setBebanAdminRekening,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Pajak Rekening',
                value: p.bebanPajakRekening,
                icon: Icons.gavel,
                onChanged: editor.setBebanPajakRekening,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Lain-lain',
                value: p.bebanLainLain,
                icon: Icons.more_horiz,
                onChanged: editor.setBebanLainLain,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Biaya Akomodasi',
                value: p.bebanBiayaAkomodasi,
                icon: Icons.hotel,
                onChanged: editor.setBebanBiayaAkomodasi,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Biaya Service Karyawan',
                value: p.bebanBiayaServiceKaryawan,
                icon: Icons.room_service,
                onChanged: editor.setBebanBiayaServiceKaryawan,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Isi HANYA jika ada beban lain di luar SC (mis. subsidi tambahan dari '
                  'usaha). Pembagian SC 5% ke karyawan tgl 15 sudah tercatat lewat '
                  'penurunan saldo Utang Service Charge di tab Neraca -- jangan '
                  'dicatat ulang di sini, supaya tidak double counting.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Penyusutan Bar',
                value: p.bebanPenyusutanBar,
                icon: Icons.local_bar,
                onChanged: editor.setBebanPenyusutanBar,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Penyusutan Kitchen',
                value: p.bebanPenyusutanKitchen,
                icon: Icons.kitchen,
                onChanged: editor.setBebanPenyusutanKitchen,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Penyusutan Furniture Area',
                value: p.bebanPenyusutanFurnitureArea,
                icon: Icons.chair,
                onChanged: editor.setBebanPenyusutanFurnitureArea,
              ),
              const SizedBox(height: 10),
              MoneyField(
                label: 'Penyusutan Office',
                value: p.bebanPenyusutanOffice,
                icon: Icons.desktop_windows,
                onChanged: editor.setBebanPenyusutanOffice,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Akun Tambahan (Beban Lain-lain)',
          icon: Icons.playlist_add,
          child: CustomAccountsSection(
            items: p.customExpenseItems,
            onItemChanged: editor.updateCustomExpenseItem,
            onItemRemoved: editor.removeCustomExpenseItem,
            onAddItem: () => showAddAccountDialog(
              context,
              title: 'Tambah Akun Beban',
              onAdd: editor.addCustomExpenseItem,
            ),
          ),
        ),
        SectionCard(
          title: 'Total Beban Operasional',
          icon: Icons.summarize,
          child: MoneyDisplayRow(
            label: 'Total',
            value: p.totalBeban,
            bold: true,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
