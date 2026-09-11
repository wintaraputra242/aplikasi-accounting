import 'fixed_asset.dart';
import 'period.dart';

/// Bangun Laporan Arus Kas (Cash Flow, metode tidak langsung) untuk periode
/// [current] dibandingkan periode sebelumnya [previous] (periode dengan
/// start_date terdekat sebelum [current] -- lihat [findPreviousPeriod]).
///
/// Karena aplikasi ini tidak mencatat mutasi kas per transaksi, arus kas
/// dihitung dari SELISIH saldo akun-akun Neraca antar 2 periode (metode tidak
/// langsung: mulai dari Laba Bersih, lalu disesuaikan dengan perubahan akun
/// non-kas). [selisih] di akhir laporan membandingkan hasil hitungan ini
/// dengan saldo Kas & Bank aktual yang diinput -- kalau tidak nol, berarti
/// ada mutasi/saldo yang belum konsisten dan perlu ditelusuri.

class ArusKasData {
  // Operasi
  final double labaBersih;
  final double penyusutan;
  final double deltaPiutang;
  final double deltaPersediaan;
  final double deltaPrepaid;
  final double deltaHutangUsaha;
  final double deltaHutangGaji;
  final double deltaHutangPajak;
  final double deltaHutangServiceCharge;
  final double deltaHutangLainLain;
  final double deltaPendapatanDiterimaDimuka;
  final double totalOperasi;

  // Investasi
  final double pembelianAsetTetap;
  final double totalInvestasi;

  // Pendanaan
  final double modalDisetor;
  final double prive;
  final double deltaPinjaman;
  final double totalPendanaan;

  final double netChangeKas;
  final double saldoKasAwal;
  final double saldoKasAkhirHitung;
  final double saldoKasAkhirAktual;
  final double selisih;

  const ArusKasData({
    required this.labaBersih,
    required this.penyusutan,
    required this.deltaPiutang,
    required this.deltaPersediaan,
    required this.deltaPrepaid,
    required this.deltaHutangUsaha,
    required this.deltaHutangGaji,
    required this.deltaHutangPajak,
    required this.deltaHutangServiceCharge,
    required this.deltaHutangLainLain,
    required this.deltaPendapatanDiterimaDimuka,
    required this.totalOperasi,
    required this.pembelianAsetTetap,
    required this.totalInvestasi,
    required this.modalDisetor,
    required this.prive,
    required this.deltaPinjaman,
    required this.totalPendanaan,
    required this.netChangeKas,
    required this.saldoKasAwal,
    required this.saldoKasAkhirHitung,
    required this.saldoKasAkhirAktual,
    required this.selisih,
  });
}

/// Cari periode dengan start_date terdekat SEBELUM [current] dari daftar
/// [allPeriods] (biasanya hasil `getAllPeriods()`) -- null kalau [current]
/// adalah periode paling awal yang tercatat.
Period? findPreviousPeriod(List<Period> allPeriods, Period current) {
  final candidates = allPeriods
      .where((p) => p.id != current.id && p.startDate.isBefore(current.startDate))
      .toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  return candidates.isEmpty ? null : candidates.first;
}

ArusKasData buildArusKas({
  required Period current,
  required Period? previous,
  required List<FixedAssetItem> fixedAssets,
}) {
  final prevPiutang = previous?.piutangUsaha ?? 0;
  final prevPersediaan = previous?.persediaanAkhir ?? 0;
  final prevPrepaid = previous?.bebanDibayarDimuka ?? 0;
  final prevHutangUsaha = previous?.hutangUsaha ?? 0;
  final prevHutangGaji = previous?.hutangGajiKaryawan ?? 0;
  final prevHutangPajak = previous?.totalHutangPajak ?? 0;
  final prevHutangServiceCharge = previous?.hutangServiceCharge ?? 0;
  final prevPendapatanDiterimaDimuka = previous?.pendapatanDiterimaDimuka ?? 0;
  final prevHutangLainLain = previous == null
      ? 0.0
      : previous.hutangLainLain +
          previous.customLiabilityItems.fold(0.0, (a, i) => a + i.value);
  final prevPinjaman = previous?.pinjaman ?? 0;
  final prevKas = previous?.totalKasBank ?? 0;

  final currentHutangLainLain =
      current.hutangLainLain + current.customLiabilityItems.fold(0.0, (a, i) => a + i.value);

  final penyusutan = current.bebanPenyusutanBar +
      current.bebanPenyusutanKitchen +
      current.bebanPenyusutanFurnitureArea +
      current.bebanPenyusutanOffice;

  final deltaPiutang = current.piutangUsaha - prevPiutang;
  final deltaPersediaan = current.persediaanAkhir - prevPersediaan;
  final deltaPrepaid = current.bebanDibayarDimuka - prevPrepaid;
  final deltaHutangUsaha = current.hutangUsaha - prevHutangUsaha;
  final deltaHutangGaji = current.hutangGajiKaryawan - prevHutangGaji;
  final deltaHutangPajak = current.totalHutangPajak - prevHutangPajak;
  final deltaHutangServiceCharge = current.hutangServiceCharge - prevHutangServiceCharge;
  final deltaHutangLainLain = currentHutangLainLain - prevHutangLainLain;
  final deltaPendapatanDiterimaDimuka =
      current.pendapatanDiterimaDimuka - prevPendapatanDiterimaDimuka;

  final totalOperasi = current.labaBersih +
      penyusutan -
      deltaPiutang -
      deltaPersediaan -
      deltaPrepaid +
      deltaHutangUsaha +
      deltaHutangGaji +
      deltaHutangPajak +
      deltaHutangServiceCharge +
      deltaHutangLainLain +
      deltaPendapatanDiterimaDimuka;

  final pembelianAsetTetap = fixedAssets
      .where((a) =>
          !a.tanggalBeli.isBefore(current.startDate) && !a.tanggalBeli.isAfter(current.endDate))
      .fold(0.0, (a, x) => a + x.hargaPerolehan);
  final totalInvestasi = -pembelianAsetTetap;

  final deltaPinjaman = current.pinjaman - prevPinjaman;
  final totalPendanaan = current.modalDisetorPeriodeIni - current.privePeriodeIni + deltaPinjaman;

  final netChangeKas = totalOperasi + totalInvestasi + totalPendanaan;
  final saldoKasAkhirHitung = prevKas + netChangeKas;
  final saldoKasAkhirAktual = current.totalKasBank;

  return ArusKasData(
    labaBersih: current.labaBersih,
    penyusutan: penyusutan,
    deltaPiutang: deltaPiutang,
    deltaPersediaan: deltaPersediaan,
    deltaPrepaid: deltaPrepaid,
    deltaHutangUsaha: deltaHutangUsaha,
    deltaHutangGaji: deltaHutangGaji,
    deltaHutangPajak: deltaHutangPajak,
    deltaHutangServiceCharge: deltaHutangServiceCharge,
    deltaHutangLainLain: deltaHutangLainLain,
    deltaPendapatanDiterimaDimuka: deltaPendapatanDiterimaDimuka,
    totalOperasi: totalOperasi,
    pembelianAsetTetap: pembelianAsetTetap,
    totalInvestasi: totalInvestasi,
    modalDisetor: current.modalDisetorPeriodeIni,
    prive: current.privePeriodeIni,
    deltaPinjaman: deltaPinjaman,
    totalPendanaan: totalPendanaan,
    netChangeKas: netChangeKas,
    saldoKasAwal: prevKas,
    saldoKasAkhirHitung: saldoKasAkhirHitung,
    saldoKasAkhirAktual: saldoKasAkhirAktual,
    selisih: saldoKasAkhirAktual - saldoKasAkhirHitung,
  );
}
