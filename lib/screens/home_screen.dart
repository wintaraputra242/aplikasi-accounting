import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/period.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import 'buku_besar_screen.dart';
import 'business_profile_screen.dart';
import 'fixed_asset_register_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_history_screen.dart';
import 'jurnal_penyesuaian_screen.dart';
import 'kas_transaksi_screen.dart';
import 'master_barang_screen.dart';
import 'neraca_saldo_gl_screen.dart';
import 'period_detail_screen.dart';
import 'rekonsiliasi_bank_screen.dart';
import 'ringkasan_tahunan_screen.dart';

/// Pilihan menu "titik tiga" di AppBar Home -- disisakan cuma aksi
/// maintenance (backup/restore/profil usaha). Fitur-fitur utama (Invoice,
/// Master Barang, dst) sekarang tampil langsung sebagai quick-nav grid di
/// body (lihat design.md §4 "Home/Dashboard") supaya tidak perlu buka menu
/// titik tiga dulu.
enum _MenuAction { profilUsaha, backup, restore }

/// Halaman utama: daftar periode pembukuan yang sudah dibuat, dan tombol
/// untuk menambah periode baru (bulanan atau rentang tanggal custom).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Period>> _future;
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getAllPeriods();
  }

  Future<void> _refresh() async {
    final future = DatabaseHelper.instance.getAllPeriods();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openPeriod(Period p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PeriodDetailScreen(periodId: p.id!)),
    );
    await _refresh();
  }

  Future<void> _addPeriod() async {
    final choice = await showDialog<_NewPeriodChoice>(
      context: context,
      builder: (_) => const _AddPeriodDialog(),
    );
    if (choice == null) return;

    Period period;
    try {
      if (choice.type == PeriodType.calendar) {
        final existing =
            await DatabaseHelper.instance.getCalendarPeriod(choice.month!, choice.year!);
        period = existing ??
            await DatabaseHelper.instance.createCalendarPeriod(choice.month!, choice.year!);
      } else {
        period = await DatabaseHelper.instance.createCustomPeriod(
          startDate: choice.start!,
          endDate: choice.end!,
          customLabel: choice.label,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat periode: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // Periode sudah tersimpan di database pada titik ini. Refresh daftar
    // segera supaya langsung muncul walaupun pengguna belum sempat masuk
    // atau langsung menekan back dari layar detail.
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Periode "${period.label}" berhasil dibuat & tersimpan.')),
    );

    await _openPeriod(period);
  }

  Future<void> _backupDatabase() async {
    setState(() => _backingUp = true);
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      final bytes = await File(dbPath).readAsBytes();
      final tanggal = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup Database',
        fileName: 'backup_aplikasi_accounting_$tanggal.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup database tersimpan di: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  /// Pulihkan database dari file backup `.db` yang dipilih user -- dipakai
  /// mis. setelah aplikasi diinstal ulang & datanya hilang. File database
  /// yang aktif ditimpa langsung dengan isi file backup, lalu daftar
  /// periode dimuat ulang di layar ini tanpa perlu restart aplikasi (kalau
  /// versi skema backup lebih lama, migrasi otomatis tetap jalan seperti
  /// biasa saat file dibuka ulang).
  Future<void> _restoreDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text(
          'Semua data yang ada di aplikasi SEKARANG akan diganti dengan isi '
          'file backup yang dipilih. Data yang belum di-backup akan hilang '
          'permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    setState(() => _restoring = true);
    try {
      final dbPath = await DatabaseHelper.instance.databasePath;
      // Tulis ke file sementara dulu baru rename menimpa yang asli --
      // supaya kalau penulisan gagal di tengah jalan (mis. disk penuh),
      // database yang sedang dipakai tidak ikut rusak.
      final tmpFile = File('$dbPath.restore_tmp');
      await tmpFile.writeAsBytes(bytes, flush: true);
      await DatabaseHelper.instance.closeDatabase();
      await tmpFile.rename(dbPath);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore berhasil. Data sudah dimuat ulang.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal restore database: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _confirmDelete(Period p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${p.label}?'),
        content: const Text('Semua data pada periode ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deletePeriod(p.id!);
      await _refresh();
    }
  }

  void _onMenuSelected(_MenuAction action) {
    if (action == _MenuAction.profilUsaha) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileScreen()));
    } else if (action == _MenuAction.backup) {
      _backupDatabase();
    } else if (action == _MenuAction.restore) {
      _restoreDatabase();
    }
  }

  void _openScreen(Widget Function() builder) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/mangana_icon.png', height: 28),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(child: Text('Mangana Coffee & Space', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          const _ThemeModeButton(),
          if (_backingUp || _restoring)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_MenuAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Menu Lainnya',
              onSelected: _onMenuSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MenuAction.profilUsaha,
                  child: _MenuRow(icon: Icons.storefront_outlined, label: 'Profil Usaha'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.backup,
                  child: _MenuRow(icon: Icons.backup_outlined, label: 'Backup Database'),
                ),
                PopupMenuItem(
                  value: _MenuAction.restore,
                  child: _MenuRow(icon: Icons.settings_backup_restore, label: 'Restore Database'),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Period>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final periods = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxxl,
              ),
              children: [
                if (periods.isNotEmpty) ...[
                  _DashboardSummaryRow(latest: periods.first),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const _AkuntansiLanjutanSection(),
                const SizedBox(height: AppSpacing.xl),
                _FiturLainnyaSection(onOpen: _openScreen),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text('Pembukuan Periode', style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (periods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Belum ada periode.\nTekan tombol "Periode Baru" untuk mulai.',
                      ctaLabel: 'Periode Baru',
                      onCta: _addPeriod,
                    ),
                  )
                else
                  for (final p in periods) _PeriodCard(period: p, onTap: _openPeriod, onDelete: _confirmDelete),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPeriod,
        icon: const Icon(Icons.add),
        label: const Text('Periode Baru'),
      ),
    );
  }
}

/// Tombol toggle mode tampilan di AppBar Home -- tekan untuk siklus Ikuti
/// Sistem -> Terang -> Gelap -> kembali ke Ikuti Sistem (lihat
/// [ThemeController]). Ikon & tooltip berubah sesuai mode aktif supaya
/// statusnya kelihatan tanpa perlu buka menu.
class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final (icon, label) = switch (controller.mode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'Ikuti Sistem'),
      ThemeMode.light => (Icons.light_mode_outlined, 'Mode Terang'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Mode Gelap'),
    };
    return IconButton(
      icon: Icon(icon),
      tooltip: '$label (tekan untuk ganti mode tampilan)',
      onPressed: controller.cycle,
    );
  }
}

/// Baris kartu ringkasan dashboard (Kas, Laba periode berjalan, Piutang,
/// Hutang Usaha) berbasis data periode TERBARU -- 2x2 di layar sempit, 4
/// kolom di layar lebar. Lihat design.md §3 "Kartu ringkasan dashboard" & §4
/// "Home/Dashboard".
class _DashboardSummaryRow extends StatelessWidget {
  final Period latest;
  const _DashboardSummaryRow({required this.latest});

  @override
  Widget build(BuildContext context) {
    final labaPositif = latest.labaBersih >= 0;
    final metrics = [
      _DashboardMetric(
        label: 'Kas & Bank Saat Ini',
        value: latest.totalKasBank,
        icon: Icons.account_balance_wallet_outlined,
      ),
      _DashboardMetric(
        label: 'Laba Periode Berjalan',
        value: latest.labaBersih,
        icon: labaPositif ? Icons.trending_up : Icons.trending_down,
        tone: labaPositif ? AppStatusTone.success : AppStatusTone.danger,
      ),
      _DashboardMetric(
        label: 'Piutang Usaha',
        value: latest.piutangUsaha,
        icon: Icons.arrow_downward,
      ),
      _DashboardMetric(
        label: 'Hutang Usaha',
        value: latest.hutangUsaha,
        icon: Icons.arrow_upward,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: metrics,
        );
      },
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final AppStatusTone? tone;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final trendColor = switch (tone) {
      AppStatusTone.success => semantic.success,
      AppStatusTone.danger => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: trendColor),
          const Spacer(),
          Text(
            formatRupiah(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: moneyStyle(context, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Entry point terpisah secara visual untuk sistem Jurnal Umum/GL --
/// aksen `secondary` (netral gelap, bukan oranye brand) + badge "Akuntansi
/// Lanjutan", supaya terasa sebagai "ruang" berbeda dari Pembukuan Periode.
/// Lihat design.md §3 & §4.
class _AkuntansiLanjutanSection extends StatelessWidget {
  const _AkuntansiLanjutanSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_QuickNavTile>[
      _QuickNavTile(Icons.payments_outlined, 'Transaksi Kas', () => const KasTransaksiScreen()),
      _QuickNavTile(Icons.menu_book_outlined, 'Buku Besar', () => const BukuBesarScreen()),
      _QuickNavTile(Icons.balance_outlined, 'Neraca Saldo (GL)', () => const NeracaSaldoGlScreen()),
      _QuickNavTile(Icons.tune, 'Jurnal Penyesuaian', () => const JurnalPenyesuaianScreen()),
      _QuickNavTile(
          Icons.account_balance_outlined, 'Rekonsiliasi Bank', () => const RekonsiliasiBankScreen()),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 20, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Akuntansi Lanjutan (Jurnal Umum & GL)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickNavGrid(items: items, accentColor: scheme.secondary),
        ],
      ),
    );
  }
}

/// Grid quick-nav ke fitur pendukung (Invoice, Master Barang, dst) --
/// menggantikan menu titik tiga panjang yang sebelumnya menyembunyikan
/// fitur-fitur ini. Lihat design.md §4.
class _FiturLainnyaSection extends StatelessWidget {
  final void Function(Widget Function() builder) onOpen;
  const _FiturLainnyaSection({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = <_QuickNavTile>[
      _QuickNavTile(Icons.request_quote_outlined, 'Buat Invoice', () => const InvoiceFormScreen()),
      _QuickNavTile(Icons.history, 'Riwayat Invoice', () => const InvoiceHistoryScreen()),
      _QuickNavTile(
          Icons.calendar_view_month, 'Ringkasan Tahunan', () => const RingkasanTahunanScreen()),
      _QuickNavTile(Icons.inventory_2_outlined, 'Master Barang', () => const MasterBarangScreen()),
      _QuickNavTile(Icons.inventory, 'Fixed Asset Register', () => const FixedAssetRegisterScreen()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text('Fitur Lainnya', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        _QuickNavGrid(items: items),
      ],
    );
  }
}

class _QuickNavTile {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  const _QuickNavTile(this.icon, this.label, this.builder);
}

class _QuickNavGrid extends StatelessWidget {
  final List<_QuickNavTile> items;
  final Color? accentColor;
  const _QuickNavGrid({required this.items, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accentColor ?? scheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1024
            ? 5
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.4,
          children: [
            for (final item in items)
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item.builder()),
                ),
                icon: Icon(item.icon, size: 18, color: color),
                label: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                ),
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
              ),
          ],
        );
      },
    );
  }
}

/// Satu baris periode di daftar "Pembukuan Periode" -- badge Laba/Rugi pakai
/// [StatusBadge] (token warna semantik baru) menggantikan CircleAvatar warna
/// hardcode sebelumnya.
class _PeriodCard extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onTap;
  final ValueChanged<Period> onDelete;

  const _PeriodCard({required this.period, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final labaBersih = period.labaBersih;
    final positive = labaBersih >= 0;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        title: Text(period.label, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: StatusBadge(
            label: '${positive ? "Laba" : "Rugi"} ${formatRupiah(labaBersih)}',
            tone: positive ? AppStatusTone.success : AppStatusTone.danger,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus periode',
              onPressed: () => onDelete(period),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onTap(period),
      ),
    );
  }
}

/// Hasil pilihan pengguna dari [_AddPeriodDialog].
class _NewPeriodChoice {
  final PeriodType type;
  final int? month;
  final int? year;
  final DateTime? start;
  final DateTime? end;
  final String? label;

  _NewPeriodChoice.calendar(this.month, this.year)
      : type = PeriodType.calendar,
        start = null,
        end = null,
        label = null;

  _NewPeriodChoice.custom(this.start, this.end, this.label)
      : type = PeriodType.custom,
        month = null,
        year = null;
}

class _AddPeriodDialog extends StatefulWidget {
  const _AddPeriodDialog();

  @override
  State<_AddPeriodDialog> createState() => _AddPeriodDialogState();
}

class _AddPeriodDialogState extends State<_AddPeriodDialog> {
  final _now = DateTime.now();
  PeriodType _type = PeriodType.calendar;

  late int _month = _now.month;
  late int _year = _now.year;

  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_rangeStart ?? _now) : (_rangeEnd ?? _rangeStart ?? _now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_now.year - 3),
      lastDate: DateTime(_now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
        if (_rangeEnd != null && _rangeEnd!.isBefore(picked)) _rangeEnd = null;
      } else {
        _rangeEnd = picked;
      }
    });
  }

  bool get _canSubmit {
    if (_type == PeriodType.calendar) return true;
    return _rangeStart != null && _rangeEnd != null && !_rangeEnd!.isBefore(_rangeStart!);
  }

  void _submit() {
    if (!_canSubmit) return;
    if (_type == PeriodType.calendar) {
      Navigator.pop(context, _NewPeriodChoice.calendar(_month, _year));
    } else {
      final label = _labelController.text.trim();
      Navigator.pop(
        context,
        _NewPeriodChoice.custom(_rangeStart!, _rangeEnd!, label.isEmpty ? null : label),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    return AlertDialog(
      title: const Text('Tambah Periode Baru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<PeriodType>(
              segments: const [
                ButtonSegment(
                  value: PeriodType.calendar,
                  label: Text('Bulanan'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: PeriodType.custom,
                  label: Text('Rentang Tanggal'),
                  icon: Icon(Icons.date_range),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            if (_type == PeriodType.calendar) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bulan'),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(Period.monthNames[m - 1]),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _month = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tahun'),
                      items: List.generate(6, (i) => _now.year - 2 + i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Cocok untuk siklus laporan yang tidak mengikuti bulan kalender, '
                'mis. 26 Juni - 25 Juli.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isStart: true),
                icon: const Icon(Icons.event),
                label: Text(_rangeStart == null ? 'Pilih Tanggal Mulai' : dateFmt.format(_rangeStart!)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isStart: false),
                icon: const Icon(Icons.event),
                label: Text(_rangeEnd == null ? 'Pilih Tanggal Akhir' : dateFmt.format(_rangeEnd!)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (opsional)',
                  hintText: 'mis. Periode Juni-Juli',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _canSubmit ? _submit : null, child: const Text('Buat')),
      ],
    );
  }
}

/// Baris ikon + label dipakai tiap [PopupMenuItem] di menu titik tiga Home
/// -- [PopupMenuItem] sendiri tidak punya parameter `leading` seperti
/// [ListTile], jadi disusun manual lewat [Row].
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
