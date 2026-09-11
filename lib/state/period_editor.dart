import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/period.dart';
import '../services/excel_parser.dart';

/// State untuk satu periode yang sedang dibuka/diedit. Setiap perubahan
/// field otomatis disimpan ke database lokal (debounce 600ms) sehingga
/// pengguna tidak perlu menekan tombol "Simpan" manual.
class PeriodEditor extends ChangeNotifier {
  Period _period;
  Timer? _debounce;
  bool isSaving = false;

  PeriodEditor(this._period);

  Period get period => _period;

  void _update(Period Function(Period) updater) {
    _period = updater(_period);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    isSaving = true;
    notifyListeners();
    await DatabaseHelper.instance.updatePeriod(_period);
    isSaving = false;
    notifyListeners();
  }

  /// Simpan segera, mis. dipanggil saat layar ditutup.
  Future<void> saveNow() async {
    _debounce?.cancel();
    await _save();
  }

  // --- Penjualan ---
  void setPenjualanCash(double v) => _update((p) => p.copyWith(penjualanCash: v));
  void setPenjualanQrisMandiri(double v) => _update((p) => p.copyWith(penjualanQrisMandiri: v));
  void setPenjualanEdcOnUs(double v) => _update((p) => p.copyWith(penjualanEdcOnUs: v));
  void setPenjualanEdcOffUs(double v) => _update((p) => p.copyWith(penjualanEdcOffUs: v));
  void setPenjualanGofood(double v) => _update((p) => p.copyWith(penjualanGofood: v));
  void setPenjualanGrabfood(double v) => _update((p) => p.copyWith(penjualanGrabfood: v));
  void setPenjualanQrisEsb(double v) => _update((p) => p.copyWith(penjualanQrisEsb: v));
  void setPenjualanOther(double v) => _update((p) => p.copyWith(penjualanOther: v));
  void setPendapatanBunga(double v) => _update((p) => p.copyWith(pendapatanBunga: v));
  void setScTerkumpul(double v) => _update((p) => p.copyWith(scTerkumpul: v));

  void applyPenjualanExcel(PenjualanParseResult result) {
    _update((p) => p.copyWith(
          penjualanCash: result.totals['cash'],
          penjualanQrisMandiri: result.totals['qris_mandiri'],
          penjualanEdcOnUs: result.totals['edc_on_us'],
          penjualanEdcOffUs: result.totals['edc_off_us'],
          penjualanGofood: result.totals['gofood'],
          penjualanGrabfood: result.totals['grabfood'],
          penjualanQrisEsb: result.totals['qris_esb'],
          penjualanOther: result.totals['other'],
          pendapatanBunga: result.totals['bunga'],
        ));
  }

  // --- Pembelian ---
  void setSaldoAwal(double v) => _update((p) => p.copyWith(saldoAwal: v));
  void setPersediaanAkhir(double v) => _update((p) => p.copyWith(persediaanAkhir: v));

  void applyPembelianExcel(PembelianParseResult result) {
    _update((p) => p.copyWith(totalPembelianBahanBaku: result.total));
  }

  void setTotalPembelianBahanBaku(double v) =>
      _update((p) => p.copyWith(totalPembelianBahanBaku: v));

  // --- Beban operasional ---
  void setBebanGajiKaryawan(double v) => _update((p) => p.copyWith(bebanGajiKaryawan: v));
  void setBebanListrikBulanan(double v) => _update((p) => p.copyWith(bebanListrikBulanan: v));
  void setBebanListrikDuaMingguan(double v) =>
      _update((p) => p.copyWith(bebanListrikDuaMingguan: v));
  void setBebanIpl(double v) => _update((p) => p.copyWith(bebanIpl: v));
  void setBebanSuppliesCleaning(double v) => _update((p) => p.copyWith(bebanSuppliesCleaning: v));
  void setBebanMdrQris(double v) => _update((p) => p.copyWith(bebanMdrQris: v));
  void setBebanMdrEdc(double v) => _update((p) => p.copyWith(bebanMdrEdc: v));
  void setBebanMdrEsb(double v) => _update((p) => p.copyWith(bebanMdrEsb: v));
  void setBebanMdrGofood(double v) => _update((p) => p.copyWith(bebanMdrGofood: v));
  void setBebanMdrGrabfood(double v) => _update((p) => p.copyWith(bebanMdrGrabfood: v));
  void setBebanMarketing(double v) => _update((p) => p.copyWith(bebanMarketing: v));
  void setBebanAdmTransfer(double v) => _update((p) => p.copyWith(bebanAdmTransfer: v));
  void setBebanKartuDebit(double v) => _update((p) => p.copyWith(bebanKartuDebit: v));
  void setBebanAdminRekening(double v) => _update((p) => p.copyWith(bebanAdminRekening: v));
  void setBebanPajakRekening(double v) => _update((p) => p.copyWith(bebanPajakRekening: v));
  void setBebanLainLain(double v) => _update((p) => p.copyWith(bebanLainLain: v));
  void setBebanBiayaAkomodasi(double v) => _update((p) => p.copyWith(bebanBiayaAkomodasi: v));
  void setBebanBiayaServiceKaryawan(double v) =>
      _update((p) => p.copyWith(bebanBiayaServiceKaryawan: v));
  void setBebanPenyusutanBar(double v) => _update((p) => p.copyWith(bebanPenyusutanBar: v));
  void setBebanPenyusutanKitchen(double v) => _update((p) => p.copyWith(bebanPenyusutanKitchen: v));
  void setBebanPenyusutanFurnitureArea(double v) =>
      _update((p) => p.copyWith(bebanPenyusutanFurnitureArea: v));
  void setBebanPenyusutanOffice(double v) => _update((p) => p.copyWith(bebanPenyusutanOffice: v));
  void setBebanWasteBahanBaku(double v) => _update((p) => p.copyWith(bebanWasteBahanBaku: v));

  // --- Akun tambahan (tombol "+ Tambah Akun") ---
  String _newCustomItemId() => DateTime.now().microsecondsSinceEpoch.toString();

  void addCustomIncomeItem(String label) {
    final item = CustomLineItem(id: _newCustomItemId(), label: label);
    _update((p) => p.copyWith(customIncomeItems: [...p.customIncomeItems, item]));
  }

  void updateCustomIncomeItem(CustomLineItem item) {
    _update((p) => p.copyWith(
          customIncomeItems: [
            for (final i in p.customIncomeItems) i.id == item.id ? item : i,
          ],
        ));
  }

  void removeCustomIncomeItem(String id) {
    _update((p) => p.copyWith(
          customIncomeItems: p.customIncomeItems.where((i) => i.id != id).toList(),
        ));
  }

  void addCustomExpenseItem(String label) {
    final item = CustomLineItem(id: _newCustomItemId(), label: label);
    _update((p) => p.copyWith(customExpenseItems: [...p.customExpenseItems, item]));
  }

  void updateCustomExpenseItem(CustomLineItem item) {
    _update((p) => p.copyWith(
          customExpenseItems: [
            for (final i in p.customExpenseItems) i.id == item.id ? item : i,
          ],
        ));
  }

  void removeCustomExpenseItem(String id) {
    _update((p) => p.copyWith(
          customExpenseItems: p.customExpenseItems.where((i) => i.id != id).toList(),
        ));
  }

  // --- Neraca: Kas & Bank (dinamis, tombol "+ Tambah Akun") ---
  void addKasBankItem(String label) {
    final item = CustomLineItem(id: _newCustomItemId(), label: label);
    _update((p) => p.copyWith(kasBankItems: [...p.kasBankItems, item]));
  }

  void updateKasBankItem(CustomLineItem item) {
    _update((p) => p.copyWith(
          kasBankItems: [
            for (final i in p.kasBankItems) i.id == item.id ? item : i,
          ],
        ));
  }

  void removeKasBankItem(String id) {
    _update((p) => p.copyWith(
          kasBankItems: p.kasBankItems.where((i) => i.id != id).toList(),
        ));
  }

  // --- Neraca: Aset Lancar Lainnya ---
  void setPiutangUsaha(double v) => _update((p) => p.copyWith(piutangUsaha: v));
  void setBebanDibayarDimuka(double v) => _update((p) => p.copyWith(bebanDibayarDimuka: v));

  void addCustomCurrentAssetItem(String label) {
    final item = CustomLineItem(id: _newCustomItemId(), label: label);
    _update((p) => p.copyWith(
          customCurrentAssetItems: [...p.customCurrentAssetItems, item],
        ));
  }

  void updateCustomCurrentAssetItem(CustomLineItem item) {
    _update((p) => p.copyWith(
          customCurrentAssetItems: [
            for (final i in p.customCurrentAssetItems) i.id == item.id ? item : i,
          ],
        ));
  }

  void removeCustomCurrentAssetItem(String id) {
    _update((p) => p.copyWith(
          customCurrentAssetItems:
              p.customCurrentAssetItems.where((i) => i.id != id).toList(),
        ));
  }

  // --- Neraca: Hutang / Liabilitas ---
  void setHutangUsaha(double v) => _update((p) => p.copyWith(hutangUsaha: v));
  void setHutangGajiKaryawan(double v) => _update((p) => p.copyWith(hutangGajiKaryawan: v));
  void setHutangPb1(double v) => _update((p) => p.copyWith(hutangPb1: v));
  void setHutangPph21(double v) => _update((p) => p.copyWith(hutangPph21: v));
  void setHutangPph23(double v) => _update((p) => p.copyWith(hutangPph23: v));
  void setHutangPajakBadan(double v) => _update((p) => p.copyWith(hutangPajakBadan: v));
  void setHutangServiceCharge(double v) => _update((p) => p.copyWith(hutangServiceCharge: v));
  void setHutangLainLain(double v) => _update((p) => p.copyWith(hutangLainLain: v));
  void setPendapatanDiterimaDimuka(double v) =>
      _update((p) => p.copyWith(pendapatanDiterimaDimuka: v));
  void setPinjaman(double v) => _update((p) => p.copyWith(pinjaman: v));

  void addCustomLiabilityItem(String label) {
    final item = CustomLineItem(id: _newCustomItemId(), label: label);
    _update((p) => p.copyWith(customLiabilityItems: [...p.customLiabilityItems, item]));
  }

  void updateCustomLiabilityItem(CustomLineItem item) {
    _update((p) => p.copyWith(
          customLiabilityItems: [
            for (final i in p.customLiabilityItems) i.id == item.id ? item : i,
          ],
        ));
  }

  void removeCustomLiabilityItem(String id) {
    _update((p) => p.copyWith(
          customLiabilityItems: p.customLiabilityItems.where((i) => i.id != id).toList(),
        ));
  }

  // --- Tax Control ---
  void setPbjtTaxPaid(double v) => _update((p) => p.copyWith(pbjtTaxPaid: v));
  void setPbjtTaxFund(double v) => _update((p) => p.copyWith(pbjtTaxFund: v));
  void setPphFinalTaxPaid(double v) => _update((p) => p.copyWith(pphFinalTaxPaid: v));
  void setPphFinalTaxFund(double v) => _update((p) => p.copyWith(pphFinalTaxFund: v));

  // --- Neraca: Modal & Prive Periode Ini ---
  void setModalDisetorPeriodeIni(double v) =>
      _update((p) => p.copyWith(modalDisetorPeriodeIni: v));
  void setPrivePeriodeIni(double v) => _update((p) => p.copyWith(privePeriodeIni: v));

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
