import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/business_profile.dart';
import '../widgets/common_widgets.dart';

/// Layar Profil Usaha: nama usaha, alamat, rekening bank, dan kontak person
/// -- dipakai berulang tiap kali generate invoice (lihat [InvoiceFormScreen]),
/// termasuk kotak kontak person di pojok kanan bawah invoice.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool _loading = true;
  bool _saving = false;

  final _namaUsaha = TextEditingController();
  final _alamatUsaha = TextEditingController();
  final _metodePembayaran = TextEditingController();
  final _namaBank = TextEditingController();
  final _namaAkunBank = TextEditingController();
  final _noRekening = TextEditingController();
  final _kodeInvoice = TextEditingController();
  final _namaKontak = TextEditingController();
  final _noKontak = TextEditingController();
  int _nextInvoiceSeq = 1;
  double _modalAwalUsaha = 0;
  double _pctReserve = 1;
  double _pctMaintenance = 1;
  double _pctNextBusinessFund = 1.5;
  int _cashReserveBulan = 4;
  double _pbjtTaxRatePersen = 10;
  double _pphFinalTaxRatePersen = 0.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    _namaUsaha.text = profile.namaUsaha;
    _alamatUsaha.text = profile.alamatUsaha;
    _metodePembayaran.text = profile.metodePembayaran;
    _namaBank.text = profile.namaBank;
    _namaAkunBank.text = profile.namaAkunBank;
    _noRekening.text = profile.noRekening;
    _kodeInvoice.text = profile.kodeInvoice;
    _namaKontak.text = profile.namaKontak;
    _noKontak.text = profile.noKontak;
    _nextInvoiceSeq = profile.nextInvoiceSeq;
    _modalAwalUsaha = profile.modalAwalUsaha;
    _pctReserve = profile.pctReserve;
    _pctMaintenance = profile.pctMaintenance;
    _pctNextBusinessFund = profile.pctNextBusinessFund;
    _cashReserveBulan = profile.cashReserveBulan;
    _pbjtTaxRatePersen = profile.pbjtTaxRatePersen;
    _pphFinalTaxRatePersen = profile.pphFinalTaxRatePersen;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = BusinessProfile(
      namaUsaha: _namaUsaha.text.trim(),
      alamatUsaha: _alamatUsaha.text.trim(),
      metodePembayaran:
          _metodePembayaran.text.trim().isEmpty ? 'Bank Transfer' : _metodePembayaran.text.trim(),
      namaBank: _namaBank.text.trim(),
      namaAkunBank: _namaAkunBank.text.trim(),
      noRekening: _noRekening.text.trim(),
      kodeInvoice: _kodeInvoice.text.trim(),
      namaKontak: _namaKontak.text.trim(),
      noKontak: _noKontak.text.trim(),
      nextInvoiceSeq: _nextInvoiceSeq,
      modalAwalUsaha: _modalAwalUsaha,
      pctReserve: _pctReserve,
      pctMaintenance: _pctMaintenance,
      pctNextBusinessFund: _pctNextBusinessFund,
      cashReserveBulan: _cashReserveBulan,
      pbjtTaxRatePersen: _pbjtTaxRatePersen,
      pphFinalTaxRatePersen: _pphFinalTaxRatePersen,
    );
    await DatabaseHelper.instance.saveBusinessProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil usaha tersimpan.')),
    );
    Navigator.of(context).pop(profile);
  }

  @override
  void dispose() {
    _namaUsaha.dispose();
    _alamatUsaha.dispose();
    _metodePembayaran.dispose();
    _namaBank.dispose();
    _namaAkunBank.dispose();
    _noRekening.dispose();
    _kodeInvoice.dispose();
    _namaKontak.dispose();
    _noKontak.dispose();
    super.dispose();
  }

  Widget _percentField(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value == value.roundToDouble() ? value.toInt().toString() : value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: label,
          suffixText: '%',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
      ),
    );
  }

  Widget _intField(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'bulan',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Usaha')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SectionCard(
                  title: 'Identitas Usaha',
                  icon: Icons.storefront,
                  child: Column(
                    children: [
                      _field(_namaUsaha, 'Nama Usaha', icon: Icons.storefront),
                      _field(_alamatUsaha, 'Alamat Usaha', maxLines: 2, icon: Icons.location_on),
                      _field(_kodeInvoice, 'Kode Invoice (opsional, mis. MCS)', icon: Icons.tag),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Info Pembayaran',
                  icon: Icons.account_balance,
                  child: Column(
                    children: [
                      _field(_metodePembayaran, 'Metode Pembayaran', icon: Icons.payments),
                      _field(_namaBank, 'Nama Bank', icon: Icons.account_balance),
                      _field(_namaAkunBank, 'Nama Pemilik Rekening', icon: Icons.person),
                      _field(_noRekening, 'No. Rekening', icon: Icons.numbers),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Modal Usaha',
                  icon: Icons.savings,
                  trailing: const Tooltip(
                    message: 'Basis Ekuitas di tab Neraca -- nilai tetap, sekali diisi',
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  child: MoneyField(
                    label: 'Modal Awal Usaha',
                    value: _modalAwalUsaha,
                    icon: Icons.savings,
                    onChanged: (v) => setState(() => _modalAwalUsaha = v),
                  ),
                ),
                SectionCard(
                  title: 'Alokasi Laba (Ringkasan Tahunan)',
                  icon: Icons.pie_chart,
                  trailing: const Tooltip(
                    message: 'Persentase dari Omset Bersih tahunan di luar Service Charge '
                        '(SC adalah hak karyawan, bukan omset usaha) -- '
                        'sisanya otomatis jadi Owner Distribution. Diisi sekali.',
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  child: Column(
                    children: [
                      _percentField(
                        'Reserve (% dari Omset excl. SC)',
                        _pctReserve,
                        (v) => setState(() => _pctReserve = v),
                      ),
                      _percentField(
                        'Maintenance (% dari Omset excl. SC)',
                        _pctMaintenance,
                        (v) => setState(() => _pctMaintenance = v),
                      ),
                      _percentField(
                        'R&D (% dari Omset excl. SC)',
                        _pctNextBusinessFund,
                        (v) => setState(() => _pctNextBusinessFund = v),
                      ),
                      _intField(
                        'Target Cash Reserve (x rata-rata beban bulanan)',
                        _cashReserveBulan,
                        (v) => setState(() => _cashReserveBulan = v),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Tarif Pajak (Tax Control)',
                  icon: Icons.percent,
                  trailing: const Tooltip(
                    message: 'Dipakai di tab Pajak tiap periode untuk hitung Tax Payable',
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  child: Column(
                    children: [
                      _percentField(
                        'Tarif PBJT / PB1',
                        _pbjtTaxRatePersen,
                        (v) => setState(() => _pbjtTaxRatePersen = v),
                      ),
                      _percentField(
                        'Tarif PPh Final UMKM',
                        _pphFinalTaxRatePersen,
                        (v) => setState(() => _pphFinalTaxRatePersen = v),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Kontak Person',
                  icon: Icons.contact_phone,
                  trailing: const Tooltip(
                    message: 'Dicantumkan di pojok kanan bawah tiap invoice',
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  child: Column(
                    children: [
                      _field(_namaKontak, 'Nama Kontak', icon: Icons.person_outline),
                      _field(_noKontak, 'No. WA / Telepon', icon: Icons.phone),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Profil'),
                  ),
                ),
              ],
            ),
    );
  }
}
