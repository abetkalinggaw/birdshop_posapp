import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cashier_shift.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/printer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_controls.dart';
import '../widgets/cashier_shift_sheet.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/printer_settings.dart';
import '../widgets/store_data_gate.dart';

final ownerShiftsProvider = Provider<List<CashierShift>>((ref) {
  if (ref.watch(authProvider).currentUser?.isAdmin != true) return const [];
  return ref.watch(sessionProvider).shifts.toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

class OwnerShiftsScreen extends ConsumerStatefulWidget {
  const OwnerShiftsScreen({super.key});
  @override
  ConsumerState<OwnerShiftsScreen> createState() => _OwnerShiftsScreenState();
}

class _OwnerShiftsScreenState extends ConsumerState<OwnerShiftsScreen> {
  String _status = 'Semua';
  String? _cashier;
  DateTimeRange? _dates;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final shifts = ref.read(ownerShiftsProvider);
    final earliest = shifts.isEmpty ? now : shifts.last.startedAt.toLocal();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year < now.year ? earliest.year : now.year),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dates,
      helpText: 'Tanggal buka shift',
      saveText: 'Terapkan',
    );
    if (range != null && mounted) setState(() => _dates = range);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).currentUser?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Akses hanya untuk Admin.')),
      );
    }
    final all = ref.watch(ownerShiftsProvider);
    final staff = <String, String>{};
    for (final shift in all) {
      staff.putIfAbsent(shift.userId, () => shift.cashierName);
    }
    final filtered = all.where((s) {
      final day = DateUtils.dateOnly(s.startedAt.toLocal());
      return (_cashier == null || s.userId == _cashier) &&
          (_dates == null ||
              (!day.isBefore(DateUtils.dateOnly(_dates!.start)) &&
                  !day.isAfter(DateUtils.dateOnly(_dates!.end)))) &&
          switch (_status) {
            'Aktif' => s.isOpen,
            'Ditutup' => !s.isOpen,
            'Selisih' => s.difference != null && s.difference!.abs() >= .005,
            _ => true,
          };
    }).toList();
    final active = all.where((s) => s.isOpen).length;
    return StoreDataGate(
      child: Scaffold(
        backgroundColor: AppColors.surfaceBackground,
        appBar: const CustomAppBar(
          title: 'Kelola Shift',
          subtitle: 'Seluruh kasir di perangkat ini',
          leading: TopBarBackButton(),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '$active shift aktif · ${all.length - active} ditutup',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final status in [
                                'Semua',
                                'Aktif',
                                'Ditutup',
                                'Selisih',
                              ])
                                AppFilterChip(
                                  label: status,
                                  selected: _status == status,
                                  onTap: () => setState(() => _status = status),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _cashier ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kasir',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Semua kasir'),
                              ),
                              for (final entry in staff.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _cashier = value == '' ? null : value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickDates,
                                icon: const Icon(Icons.date_range_outlined),
                                label: Text(
                                  _dates == null
                                      ? 'Semua tanggal buka'
                                      : '${DateFormat('dd MMM yy').format(_dates!.start)} – ${DateFormat('dd MMM yy').format(_dates!.end)}',
                                ),
                              ),
                              if (_dates != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _dates = null),
                                  child: const Text('Hapus tanggal'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${filtered.length} shift',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada shift untuk filter ini. Shift akan muncul setelah kasir mulai bekerja.',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final shift = filtered[index];
                          final difference = shift.difference;
                          return Material(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      OwnerShiftDetailScreen(shiftId: shift.id),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            shift.cashierName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        AppBadge(
                                          label: shift.isOpen
                                              ? 'Aktif'
                                              : 'Ditutup',
                                          tone: shift.isOpen
                                              ? AppBadgeTone.positive
                                              : AppBadgeTone.neutral,
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat('dd MMM yyyy · HH:mm')
                                          .format(shift.startedAt.toLocal()),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ShiftAmount(
                                      label: shift.isOpen
                                          ? 'Kas yang diharapkan'
                                          : 'Kas aktual',
                                      value:
                                          shift.actualCash ??
                                          shift.expectedCash,
                                      emphasis: true,
                                    ),
                                    Text(
                                      shift.isOpen
                                          ? '${shift.sales.length} transaksi · Belum dihitung akhir'
                                          : difference!.abs() < .005
                                          ? '${shift.sales.length} transaksi · Kas sesuai'
                                          : '${difference < 0 ? "Kas kurang" : "Kas lebih"} ${CurrencyFormatter.format(difference.abs())} · ${shift.sales.length} transaksi',
                                      style: TextStyle(
                                        color:
                                            difference != null &&
                                                difference.abs() >= .005
                                            ? AppColors.badgeRedText
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OwnerShiftDetailScreen extends ConsumerStatefulWidget {
  final String shiftId;
  const OwnerShiftDetailScreen({super.key, required this.shiftId});
  @override
  ConsumerState<OwnerShiftDetailScreen> createState() =>
      _OwnerShiftDetailScreenState();
}

class _OwnerShiftDetailScreenState
    extends ConsumerState<OwnerShiftDetailScreen> {
  bool _printing = false, _sent = false;

  Future<void> _print() async {
    if (_printing || ref.read(printerProvider).busy) return;
    final ready = await showPrinterSettings(
      context,
      selectForPrint: true,
      continueLabel: 'Lanjut Cetak',
    );
    if (ready != true || !mounted) return;
    setState(() {
      _printing = true;
      _sent = false;
    });
    final sent = await ref
        .read(printerProvider.notifier)
        .printShift(widget.shiftId);
    if (mounted) {
      setState(() {
        _printing = false;
        _sent = sent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(ownerShiftsProvider);
    final shift = shifts.where((s) => s.id == widget.shiftId).firstOrNull;
    if (shift == null) {
      return Scaffold(
        appBar: const CustomAppBar(
          title: 'Ringkasan Shift',
          leading: TopBarBackButton(),
        ),
        body: const Center(child: Text('Shift tidak tersedia untuk akun ini.')),
      );
    }
    final printer = ref.watch(printerProvider);
    return StoreDataGate(
      child: Scaffold(
        backgroundColor: AppColors.surfaceBackground,
        appBar: CustomAppBar(
          title: 'Ringkasan Shift',
          leading: const TopBarBackButton(),
          actions: [
            TopBarActionButton(
              icon: Icons.settings_outlined,
              tooltip: 'Pengaturan printer',
              onTap: () => showPrinterSettings(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      shift.id,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppBadge(
                        label: shift.isOpen
                            ? 'Shift aktif · Belum ditutup'
                            : 'Shift ditutup',
                        tone: shift.isOpen
                            ? AppBadgeTone.positive
                            : AppBadgeTone.neutral,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ShiftSummary(shift: shift),
                      ),
                    ),
                    PrinterFeedback(printer: printer, showSuccess: _sent),
                    const SizedBox(height: 24),
                    Text(
                      'Transaksi dalam shift',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (shift.sales.isEmpty)
                      const Text(
                        'Belum ada transaksi.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    for (final sale in shift.sales)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              sale.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ShiftAmount(
                              label:
                                  '${DateFormat('HH:mm').format(sale.timestamp.toLocal())} · ${sale.paymentMethod.code}',
                              value: sale.totalAmount,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: shift.isOpen
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.all(16),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: PrimaryButton(
                      text: _sent
                          ? 'Cetak Ulang Ringkasan'
                          : 'Cetak Ringkasan Shift',
                      icon: Icons.print_outlined,
                      isLoading: _printing || printer.busy,
                      onPressed: _printing || printer.busy ? null : _print,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
