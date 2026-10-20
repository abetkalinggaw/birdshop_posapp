import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cashier_shift.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'currency_formatter.dart';
import 'primary_button.dart';

Future<void> showCashierShiftSheet(
  BuildContext context, {
  CashierShift? closing,
  CashierShift? summary,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: AppColors.surfaceCard,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (_) => _ShiftSheet(closing: closing, summary: summary),
);

class _ShiftSheet extends ConsumerStatefulWidget {
  final CashierShift? closing, summary;
  const _ShiftSheet({this.closing, this.summary});
  @override
  ConsumerState<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends ConsumerState<_ShiftSheet> {
  final _form = GlobalKey<FormState>();
  final _cash = TextEditingController();
  final _note = TextEditingController();
  final _scroll = ScrollController();
  late CashierShift? _summary = widget.summary;
  bool _busy = false;
  String? _error;
  double? get _amount => double.tryParse(_cash.text);
  @override
  void dispose() {
    _cash.dispose();
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(sessionProvider.notifier);
      if (widget.closing == null) {
        await controller.openNewShift(_amount!);
        if (mounted) Navigator.pop(context);
      } else {
        final shift = await controller.closeShift(
          _amount!,
          note: _note.text,
          shiftId: widget.closing!.id,
        );
        if (mounted) {
          setState(() => _summary = shift);
          _scroll.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Shift gagal disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearCart() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text(
          'Item yang belum dibayar akan dihapus agar shift dapat ditutup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) ref.invalidate(cartProvider);
  }

  @override
  Widget build(BuildContext context) {
    final closing = widget.closing;
    final hasCart = ref.watch(cartProvider).items.isNotEmpty;
    final difference = _amount == null || closing == null
        ? null
        : _amount! - closing.expectedCash;
    final compact =
        MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom <
        240;
    final action = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: PrimaryButton(
        text: _summary != null
            ? 'Selesai'
            : closing == null
            ? 'Buka Shift & Mulai'
            : 'Simpan & Tutup Shift',
        icon: _summary != null ? Icons.check : Icons.point_of_sale_outlined,
        isLoading: _busy,
        onPressed: _summary != null ? () => Navigator.pop(context) : _submit,
      ),
    );
    return PopScope(
      canPop: !_busy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.outlineColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _summary != null
                                          ? 'Ringkasan Shift'
                                          : closing == null
                                          ? 'Buka Shift'
                                          : 'Tutup Shift',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Tutup',
                                    onPressed: _busy
                                        ? null
                                        : () => Navigator.pop(context),
                                    icon: const Icon(Icons.close),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: _summary != null
                              ? ShiftSummary(shift: _summary!)
                              : Form(
                                  key: _form,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        closing == null
                                            ? 'Hitung uang tunai di laci sebelum mulai melayani pembeli. Masukkan 0 jika tidak ada modal awal.'
                                            : 'Hitung seluruh uang tunai di laci, termasuk modal awal. Pembayaran non-tunai tidak masuk dalam hitungan kas.',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          height: 1.5,
                                        ),
                                      ),
                                      if (closing != null) ...[
                                        if (hasCart) ...[
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Keranjang masih berisi item yang belum dibayar.',
                                            style: TextStyle(
                                              color: AppColors.alertCritical,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : _clearCart,
                                            child: const Text(
                                              'Kosongkan Keranjang',
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        ShiftAmount(
                                          label: 'Modal awal',
                                          value: closing.openingCash,
                                        ),
                                        ShiftAmount(
                                          label: 'Penjualan tunai',
                                          value: closing.cashSales,
                                        ),
                                        ShiftAmount(
                                          label: 'Non-tunai',
                                          value: closing.nonCashSales,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                        ShiftAmount(
                                          label: 'Kas yang diharapkan',
                                          value: closing.expectedCash,
                                          emphasis: true,
                                        ),
                                      ],
                                      const SizedBox(height: 24),
                                      TextFormField(
                                        controller: _cash,
                                        enabled: !_busy,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(12),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: closing == null
                                              ? 'Modal awal kas'
                                              : 'Kas aktual di laci',
                                          prefixText: 'Rp ',
                                          hintText: '0',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                        validator: (_) =>
                                            _amount == null ||
                                                !_amount!.isFinite ||
                                                _amount! < 0
                                            ? 'Masukkan nominal. Gunakan 0 jika tidak ada uang tunai.'
                                            : null,
                                      ),
                                      if (closing != null) ...[
                                        const SizedBox(height: 16),
                                        if (difference != null)
                                          ShiftDifference(value: difference),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _note,
                                          enabled: !_busy,
                                          minLines: 2,
                                          maxLines: 4,
                                          maxLength: 500,
                                          decoration: InputDecoration(
                                            labelText:
                                                difference != null &&
                                                    difference.abs() >= .005
                                                ? 'Catatan selisih kas'
                                                : 'Catatan (opsional)',
                                            hintText: 'Jelaskan jika ada uang kurang atau lebih.',
                                          ),
                                          validator: (value) =>
                                              difference != null &&
                                                  difference.abs() >= .005 &&
                                                  value!.trim().isEmpty
                                              ? 'Isi catatan untuk menjelaskan selisih kas.'
                                              : null,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Shift yang sudah ditutup tidak dapat diubah. Anda dapat membuka shift baru setelahnya.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                      if (_error != null) ...[
                                        const SizedBox(height: 16),
                                        Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: AppColors.alertCritical,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                        if (compact) action,
                      ],
                    ),
                  ),
                ),
                if (!compact) action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShiftAmount extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasis;
  const ShiftAmount({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasis ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.format(value),
              style: AppNumbers.price.copyWith(fontSize: emphasis ? 20 : 16),
            ),
          ),
        ),
      ],
    ),
  );
}

class ShiftDifference extends StatelessWidget {
  final double value;
  const ShiftDifference({super.key, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value.abs() < .005
            ? 'Kas sesuai'
            : value < 0
            ? 'Kas kurang'
            : 'Kas lebih',
        style: TextStyle(
          color: value.abs() < .005
              ? AppColors.primaryGreen
              : AppColors.alertCritical,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(value.abs()),
            style: AppNumbers.total.copyWith(fontSize: 28),
          ),
        ),
      ),
    ],
  );
}

class ShiftSummary extends StatelessWidget {
  final CashierShift shift;
  const ShiftSummary({super.key, required this.shift});
  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(shift.cashierName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Buka: ${date.format(shift.startedAt.toLocal())}\nTutup: ${shift.closedAt == null ? "—" : date.format(shift.closedAt!.toLocal())}',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 24),
        if (shift.difference != null) ShiftDifference(value: shift.difference!),
        const SizedBox(height: 16),
        ShiftAmount(label: 'Modal awal', value: shift.openingCash),
        ShiftAmount(label: 'Penjualan tunai', value: shift.cashSales),
        ShiftAmount(label: 'Non-tunai', value: shift.nonCashSales),
        const Divider(height: 24),
        ShiftAmount(label: 'Kas yang diharapkan', value: shift.expectedCash),
        if (shift.actualCash != null)
          ShiftAmount(
            label: 'Kas aktual',
            value: shift.actualCash!,
            emphasis: true,
          ),
        const SizedBox(height: 16),
        Text(
          '${shift.sales.length} transaksi · Shift tersimpan di perangkat ini',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (shift.note.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(shift.note),
        ],
      ],
    );
  }
}

Future<void> showShiftHistory(
  BuildContext context,
  List<CashierShift> shifts,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (sheetContext) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Riwayat Shift',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (shifts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada shift yang ditutup.'),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shifts.length,
              itemBuilder: (_, index) {
                final shift = shifts[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(
                    DateFormat('dd MMM yyyy, HH:mm')
                        .format(shift.startedAt.toLocal()),
                  ),
                  subtitle: Text(
                    '${shift.sales.length} transaksi · ${shift.difference!.abs() < .005
                        ? "Kas sesuai"
                        : shift.difference! < 0
                        ? "Kas kurang"
                        : "Kas lebih"}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (context.mounted) {
                      await showCashierShiftSheet(context, summary: shift);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
