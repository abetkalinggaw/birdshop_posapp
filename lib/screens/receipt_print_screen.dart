import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../providers/printer_provider.dart';
import '../widgets/printer_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';

Future<void> openReceiptPrinting(
  BuildContext context,
  TransactionRecord transaction,
) async {
  final ready = await showPrinterSettings(context, selectForPrint: true);
  if (ready != true || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReceiptPrintScreen(transaction: transaction),
    ),
  );
}

class ReceiptPrintScreen extends ConsumerStatefulWidget {
  final TransactionRecord transaction;

  const ReceiptPrintScreen({super.key, required this.transaction});

  @override
  ConsumerState<ReceiptPrintScreen> createState() => _ReceiptPrintScreenState();
}

class _ReceiptPrintScreenState extends ConsumerState<ReceiptPrintScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _feed = AnimationController(vsync: this);
  final _scroll = ScrollController();
  bool _jobActive = false;
  bool _sent = false;
  Animation<double>? _entry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entry = ModalRoute.of(context)?.animation;
      if (_entry == null || _entry!.status == AnimationStatus.completed) {
        _print();
      } else {
        _entry!.addStatusListener(_onEntry);
      }
    });
  }

  void _onEntry(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _entry?.removeStatusListener(_onEntry);
      _print();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(printerProvider.notifier).refresh();
    }
  }

  Future<void> _print() async {
    if (_jobActive || ref.read(printerProvider).busy) return;
    setState(() {
      _jobActive = true;
      _sent = false;
    });
    _scroll.jumpTo(0);
    _feed.value = MediaQuery.disableAnimationsOf(context) ? 1 : 0;
    final success = await ref
        .read(printerProvider.notifier)
        .printReceipt(widget.transaction);
    if (!mounted) return;
    _feed.stop();
    _feed.value = MediaQuery.disableAnimationsOf(context) || success
        ? 1
        : ref.read(printerProvider).printProgress;
    setState(() {
      _jobActive = false;
      _sent = success;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _feed.value = 1;
    }
  }

  void _followPrint(double progress) {
    if (!_jobActive) return;
    if (MediaQuery.disableAnimationsOf(context) || progress == 1) {
      _feed.value = 1;
    } else {
      _feed.animateTo(
        progress,
        duration: const Duration(milliseconds: 60),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entry?.removeStatusListener(_onEntry);
    _feed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);
    ref.listen<double>(
      printerProvider.select((p) => p.printProgress),
      (_, value) => _followPrint(value),
    );
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: CustomAppBar(
        title: 'Cetak Struk',
        subtitle: widget.transaction.id,
        leading: const TopBarBackButton(),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedBuilder(
                    animation: _feed,
                    builder: (context, child) => Semantics(
                      liveRegion: true,
                      child: Text(
                        _jobActive
                            ? printer.printProgress == 0
                                  ? 'Menyiapkan struk…'
                                  : 'Mengirim struk…'
                            : _sent
                            ? 'Data struk terkirim'
                            : 'Cetak belum selesai',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    printer.connected
                        ? '${printer.selected?.name} · ${printer.paperMm} mm'
                        : 'Hubungkan kembali printer melalui ikon pengaturan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  PrinterFeedback(printer: printer, showSuccess: _sent),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.print_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                printer.selected?.name ?? 'Printer Bluetooth',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Pengaturan printer',
                              onPressed: () => showPrinterSettings(context),
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreenDark,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedBuilder(
                        animation: _feed,
                        child: _ReceiptPaper(transaction: widget.transaction),
                        builder: (context, child) => ClipRect(
                          child: Align(
                            key: const ValueKey('receipt-feed'),
                            alignment: Alignment.topCenter,
                            heightFactor: _feed.value,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedBuilder(
                animation: _feed,
                builder: (context, child) => PrimaryButton(
                  text: 'Ulangi Cetak',
                  isLoading: printer.busy || _jobActive,
                  icon: Icons.print_outlined,
                  onPressed: printer.busy || _jobActive ? null : _print,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptPaper extends StatelessWidget {
  final TransactionRecord transaction;

  const _ReceiptPaper({required this.transaction});

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _ReceiptEdge(),
    child: ColoredBox(
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'EX-SHA Bird Shop',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Pasar Burung Pramuka Lt. 1 No. 42\nTelp: 0812-3456-7890',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 32),
            Text(
              transaction.id,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.timestamp),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _ReceiptRow(label: 'Kasir', value: transaction.cashierName),
            _ReceiptRow(label: 'ID kasir', value: transaction.cashierId),
            _ReceiptRow(
              label: 'Pembayaran',
              value: transaction.paymentMethod.code,
            ),
            const Divider(height: 32),
            if (transaction.items.isEmpty)
              const Text('Tidak ada rincian item.'),
            ...transaction.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    _ReceiptRow(
                      label:
                          '${item.quantity} × ${CurrencyFormatter.format(item.product.price)}',
                      value: CurrencyFormatter.format(item.subtotal),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            _ReceiptRow(
              label: 'Subtotal',
              value: CurrencyFormatter.format(transaction.subtotal),
            ),
            if (transaction.memberDiscount > 0)
              _ReceiptRow(
                label: 'Diskon member',
                value:
                    '− ${CurrencyFormatter.format(transaction.memberDiscount)}',
              ),
            if (transaction.tax > 0)
              _ReceiptRow(
                label: 'Pajak',
                value: CurrencyFormatter.format(transaction.tax),
              ),
            const SizedBox(height: 16),
            const Text(
              'Total pembayaran',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.format(transaction.totalAmount),
              style: AppNumbers.metric.copyWith(color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 16),
            _ReceiptRow(
              label: 'Dibayar',
              value: CurrencyFormatter.format(transaction.receivedAmount),
            ),
            _ReceiptRow(
              label: 'Kembalian',
              value: CurrencyFormatter.format(transaction.changeAmount),
            ),
            const Divider(height: 32),
            const Text(
              'Terima kasih atas kunjungan Anda',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Barang yang dibeli tidak dapat ditukar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReceiptEdge extends CustomClipper<Path> {
  const _ReceiptEdge();

  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 6);
    final teeth = (size.width / 12).ceil();
    final step = size.width / teeth;
    for (var i = 0; i < teeth; i++) {
      path.lineTo((i + .5) * step, size.height);
      path.lineTo((i + 1) * step, size.height - 6);
    }
    return path
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(_ReceiptEdge oldClipper) => false;
}
