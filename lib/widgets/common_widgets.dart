import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/period.dart';
import '../utils/formatters.dart';

final _thousandsFormat = NumberFormat.decimalPattern('id_ID');

/// Format input nominal secara live jadi pemisah ribuan format Indonesia
/// (titik), mis. mengetik "1000000" langsung tampil "1.000.000". Kursor
/// dijaga tetap di posisi yang wajar (dihitung dari jumlah digit di kiri
/// kursor, bukan dari index karakter mentah) supaya tidak "loncat" saat
/// titik pemisah baru disisipkan/dihapus.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final digitsBeforeCursor =
        newValue.text.substring(0, newValue.selection.end).replaceAll(RegExp(r'[^0-9]'), '').length;

    final formatted = _thousandsFormat.format(int.parse(digitsOnly));

    var seen = 0;
    var cursorIndex = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        seen++;
        if (seen == digitsBeforeCursor) {
          cursorIndex = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorIndex),
    );
  }
}

/// Kartu pembungkus tiap bagian form, dengan judul & ikon konsisten.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Input nominal Rupiah. Hanya menerima angka, tanpa desimal.
class MoneyField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final IconData? icon;

  const MoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller;
  late double _lastKnownValue;

  @override
  void initState() {
    super.initState();
    _lastKnownValue = widget.value;
    _controller = TextEditingController(text: _asText(widget.value));
  }

  @override
  void didUpdateWidget(covariant MoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sinkronkan dari luar (mis. setelah load data dari database) tanpa
    // mengganggu teks saat pengguna sedang mengetik.
    if (widget.value != _lastKnownValue) {
      _lastKnownValue = widget.value;
      _controller.text = _asText(widget.value);
    }
  }

  String _asText(double v) => v == 0 ? '' : _thousandsFormat.format(v.toInt());

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, RupiahInputFormatter()],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'Rp ',
        prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (text) {
        final value = parseFlexibleNumber(text);
        _lastKnownValue = value;
        widget.onChanged(value);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Input angka desimal untuk qty/stok (mis. "2.5" kg). Beda dari
/// [MoneyField]: mengizinkan titik/koma desimal dan tidak pakai pemisah
/// ribuan atau prefix "Rp".
class QtyField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffixText;

  const QtyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffixText,
  });

  @override
  State<QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<QtyField> {
  late final TextEditingController _controller;
  late double _lastKnownValue;

  @override
  void initState() {
    super.initState();
    _lastKnownValue = widget.value;
    _controller = TextEditingController(text: _asText(widget.value));
  }

  @override
  void didUpdateWidget(covariant QtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _lastKnownValue) {
      _lastKnownValue = widget.value;
      _controller.text = _asText(widget.value);
    }
  }

  String _asText(double v) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffixText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (text) {
        final value = parseFlexibleNumber(text);
        _lastKnownValue = value;
        widget.onChanged(value);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Dialog kecil untuk menanyakan nama akun baru -- dipakai oleh tombol
/// "+ Tambah Akun" di [CustomAccountsSection]. Nominal & keterangan diisi
/// belakangan langsung di baris akun yang baru muncul, supaya dialognya
/// singkat.
Future<void> showAddAccountDialog(
  BuildContext context, {
  required String title,
  required ValueChanged<String> onAdd,
}) async {
  final controller = TextEditingController();
  final label = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nama Akun',
          hintText: 'mis. Sewa Alat',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Tambah'),
        ),
      ],
    ),
  );
  if (label != null && label.isNotEmpty) onAdd(label);
}

/// Satu baris akun tambahan: Nama Akun, Keterangan (uang ini untuk apa), dan
/// Nominal, plus tombol hapus.
class _CustomAccountRow extends StatefulWidget {
  final CustomLineItem item;
  final ValueChanged<CustomLineItem> onChanged;
  final VoidCallback onRemove;

  const _CustomAccountRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CustomAccountRow> createState() => _CustomAccountRowState();
}

class _CustomAccountRowState extends State<_CustomAccountRow> {
  late final TextEditingController _labelController;
  late final TextEditingController _keteranganController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.item.label);
    _keteranganController = TextEditingController(text: widget.item.keterangan);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Akun',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => widget.onChanged(widget.item.copyWith(label: v)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus akun',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _keteranganController,
            decoration: const InputDecoration(
              labelText: 'Keterangan (uang ini untuk apa)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => widget.onChanged(widget.item.copyWith(keterangan: v)),
          ),
          const SizedBox(height: 8),
          MoneyField(
            label: 'Nominal',
            value: widget.item.value,
            onChanged: (v) => widget.onChanged(widget.item.copyWith(value: v)),
          ),
        ],
      ),
    );
  }
}

/// Daftar akun tambahan (dinamis) untuk kategori Pendapatan/Beban Lain-lain,
/// plus tombol "+ Tambah Akun" di bawahnya. Ini menjawab keluhan "ini belum
/// masuk, itu belum masuk" -- akun baru bisa ditambah sendiri dari sini
/// tanpa perlu update aplikasi, dan otomatis ikut terhitung di Total, Neraca
/// Saldo, serta export Excel/PDF (lihat `buildPendapatanList`/`buildBebanList`
/// di `models/period.dart`).
class CustomAccountsSection extends StatelessWidget {
  final List<CustomLineItem> items;
  final ValueChanged<CustomLineItem> onItemChanged;
  final ValueChanged<String> onItemRemoved;
  final VoidCallback onAddItem;

  const CustomAccountsSection({
    super.key,
    required this.items,
    required this.onItemChanged,
    required this.onItemRemoved,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _CustomAccountRow(
            key: ValueKey(item.id),
            item: item,
            onChanged: onItemChanged,
            onRemove: () => onItemRemoved(item.id),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Akun'),
        ),
      ],
    );
  }
}

/// Dialog pemilih akun dengan pencarian (nama/kode) -- dipakai untuk pilih
/// "akun lawan" di form Kas Masuk/Keluar/Transfer (lihat
/// lib/screens/kas_transaksi_screen.dart) supaya tidak perlu scroll manual
/// di antara puluhan akun COA.
Future<Account?> pickAccount(
  BuildContext context, {
  String title = 'Pilih Akun',
  List<Account>? accounts,
  String? excludeKode,
  List<String>? excludeKodes,
}) {
  final all = (accounts ?? kChartOfAccounts)
      .where((a) => a.kode != excludeKode && !(excludeKodes?.contains(a.kode) ?? false))
      .toList();
  return showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AccountPickerSheet(title: title, accounts: all),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  final String title;
  final List<Account> accounts;

  const _AccountPickerSheet({required this.title, required this.accounts});

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.accounts
        : widget.accounts
            .where((a) =>
                a.nama.toLowerCase().contains(query) || a.kode.toLowerCase().contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Cari akun',
                      hintText: 'mis. Bank BCA, Gaji, 61.1',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Tidak ada akun cocok.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final a = filtered[i];
                        return ListTile(
                          title: Text(a.nama),
                          subtitle: Text('${a.kode} • ${a.kategori}'),
                          onTap: () => Navigator.pop(ctx, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field tampilan untuk akun yang sudah dipilih lewat [pickAccount] --
/// tampak seperti [TextFormField] read-only, tap membuka pencarian.
class AccountPickerField extends StatelessWidget {
  final String label;
  final Account? value;
  final ValueChanged<Account> onChanged;
  final List<Account>? accounts;
  final String? excludeKode;
  final List<String>? excludeKodes;

  const AccountPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.accounts,
    this.excludeKode,
    this.excludeKodes,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await pickAccount(
          context,
          title: label,
          accounts: accounts,
          excludeKode: excludeKode,
          excludeKodes: excludeKodes,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value == null ? 'Pilih akun...' : value!.label,
          style: value == null ? const TextStyle(color: Colors.black54) : null,
        ),
      ),
    );
  }
}

/// Satu baris akun+nominal untuk form yang boleh split ke lebih dari satu
/// akun sekaligus (mis. "akun lawan" di Kas Masuk/Keluar -- lihat
/// lib/screens/kas_transaksi_screen.dart).
class AccountAmountLine {
  final String id;
  final Account? akun;
  final double jumlah;

  const AccountAmountLine({required this.id, this.akun, this.jumlah = 0});

  AccountAmountLine copyWith({Account? akun, double? jumlah}) => AccountAmountLine(
        id: id,
        akun: akun ?? this.akun,
        jumlah: jumlah ?? this.jumlah,
      );
}

class _AccountAmountRow extends StatelessWidget {
  final AccountAmountLine item;
  final List<Account>? accounts;
  final List<String> excludeKodes;
  final ValueChanged<AccountAmountLine> onChanged;
  final VoidCallback onRemove;
  final bool showRemove;

  const _AccountAmountRow({
    super.key,
    required this.item,
    required this.accounts,
    required this.excludeKodes,
    required this.onChanged,
    required this.onRemove,
    required this.showRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AccountPickerField(
                  label: 'Akun',
                  value: item.akun,
                  accounts: accounts,
                  excludeKodes: excludeKodes,
                  onChanged: (a) => onChanged(item.copyWith(akun: a)),
                ),
              ),
              if (showRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus baris',
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          MoneyField(
            label: 'Nominal',
            value: item.jumlah,
            onChanged: (v) => onChanged(item.copyWith(jumlah: v)),
          ),
        ],
      ),
    );
  }
}

/// Daftar baris akun+nominal dinamis, plus tombol "+ Tambah Akun Lawan" --
/// dipakai supaya satu transaksi Kas Masuk/Keluar bisa split ke lebih dari
/// satu akun lawan (mis. sebagian pelunasan piutang, sebagian pendapatan
/// lain-lain), bukan cuma satu akun seperti sebelumnya.
class AccountAmountSplitSection extends StatelessWidget {
  final List<AccountAmountLine> items;
  final List<Account>? accounts;
  final String? excludeKode;
  final ValueChanged<AccountAmountLine> onItemChanged;
  final ValueChanged<String> onItemRemoved;
  final VoidCallback onAddItem;

  const AccountAmountSplitSection({
    super.key,
    required this.items,
    this.accounts,
    this.excludeKode,
    required this.onItemChanged,
    required this.onItemRemoved,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _AccountAmountRow(
            key: ValueKey(item.id),
            item: item,
            accounts: accounts,
            excludeKodes: [
              if (excludeKode != null) excludeKode!,
              for (final other in items)
                if (other.id != item.id && other.akun != null) other.akun!.kode,
            ],
            onChanged: onItemChanged,
            onRemove: () => onItemRemoved(item.id),
            showRemove: items.length > 1,
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Akun Lawan'),
        ),
      ],
    );
  }
}

/// Baris label - nominal, dipakai untuk menampilkan hasil kalkulasi
/// (bukan input), mis. total per kategori atau ringkasan laba.
class MoneyDisplayRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? color;

  const MoneyDisplayRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatRupiah(value), style: style),
        ],
      ),
    );
  }
}
