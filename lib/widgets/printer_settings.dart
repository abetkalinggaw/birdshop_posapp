import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/printer_provider.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

Future<bool?> showPrinterSettings(
  BuildContext context, {
  bool selectForPrint = false,
  String continueLabel = 'Lanjut Cetak Struk',
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surfaceCard,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (_) => _PrinterSettingsSheet(
    selectForPrint: selectForPrint,
    continueLabel: continueLabel,
  ),
);

class PrinterFeedback extends StatelessWidget {
  final PrinterState printer;
  final bool showSuccess;
  const PrinterFeedback({
    super.key,
    required this.printer,
    this.showSuccess = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (printer.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            printer.error!,
            style: const TextStyle(color: AppColors.badgeRedText),
          ),
        ),
      if (printer.uncertain)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Sebagian struk mungkin sudah tercetak. Periksa printer sebelum mencetak ulang.',
            style: TextStyle(
              color: AppColors.badgeRedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (showSuccess && printer.message != null && printer.error == null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            printer.message!,
            style: const TextStyle(color: AppColors.primaryGreen),
          ),
        ),
    ],
  );
}

class PrinterConnectionTile extends ConsumerWidget {
  const PrinterConnectionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printer = ref.watch(printerProvider);
    return Row(
      children: [
        Icon(
          printer.connected
              ? Icons.print_outlined
              : Icons.print_disabled_outlined,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                printer.selected?.name ?? 'Printer Bluetooth',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                printer.connected
                    ? 'Terhubung · ${printer.paperMm} mm'
                    : 'Belum terhubung · ${printer.paperMm} mm',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Kelola Printer',
          onPressed: () => showPrinterSettings(context),
          icon: const Icon(Icons.settings_bluetooth_outlined),
          color: AppColors.primaryGreen,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
  }
}

class _PrinterSettingsSheet extends ConsumerStatefulWidget {
  final bool selectForPrint;
  final String continueLabel;
  const _PrinterSettingsSheet({
    required this.selectForPrint,
    required this.continueLabel,
  });
  @override
  ConsumerState<_PrinterSettingsSheet> createState() =>
      _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState extends ConsumerState<_PrinterSettingsSheet>
    with WidgetsBindingObserver {
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing || ref.read(printerProvider).busy) return;
    setState(() => _continuing = true);
    await ref.read(printerProvider.notifier).refresh();
    if (!mounted) return;
    final printer = ref.read(printerProvider);
    if (printer.connected && printer.selected != null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _continuing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) ref.read(printerProvider.notifier).loadDevices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(printerProvider.notifier).loadDevices();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);
    final controller = ref.read(printerProvider.notifier);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectForPrint
                          ? 'Pilih Printer'
                          : 'Printer Thermal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup pengaturan printer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Gunakan printer Bluetooth Classic yang mendukung ESC/POS. Pasangkan melalui pengaturan Android terlebih dahulu.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                key: ValueKey(printer.paperMm),
                initialValue: printer.paperMm,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lebar kertas'),
                items: const [
                  DropdownMenuItem(value: 58, child: Text('58 mm · 384 dot')),
                  DropdownMenuItem(value: 80, child: Text('80 mm · 576 dot')),
                ],
                onChanged: printer.busy
                    ? null
                    : (value) {
                        if (value != null) controller.setPaper(value);
                      },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Perangkat terpasang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang printer',
                    onPressed: printer.busy ? null : controller.loadDevices,
                    icon: const Icon(Icons.refresh),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
              if (printer.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
              if (!printer.supported)
                const Text(
                  'Bluetooth Classic hanya tersedia pada perangkat Android yang mendukung Bluetooth.',
                ),
              if (!printer.busy &&
                  printer.devices.isEmpty &&
                  printer.error == null &&
                  printer.supported)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Belum ada printer terpasang. Buka pengaturan Bluetooth untuk memasangkan printer.',
                  ),
                ),
              ...printer.devices.map(
                (device) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: printer.busy
                            ? null
                            : () =>
                                  printer.connected &&
                                      printer.selected?.address ==
                                          device.address
                                  ? controller.disconnect()
                                  : controller.connect(device),
                        child: Text(
                          printer.connected &&
                                  printer.selected?.address == device.address
                              ? 'Putuskan Koneksi'
                              : 'Hubungkan',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PrinterFeedback(printer: printer),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: printer.busy
                      ? null
                      : () => controller.openSettings(),
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Pengaturan Bluetooth'),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: widget.selectForPrint
                    ? widget.continueLabel
                    : 'Tes Cetak',
                icon: Icons.print_outlined,
                isLoading: printer.busy || _continuing,
                onPressed: widget.selectForPrint
                    ? printer.connected && printer.selected != null
                          ? _continue
                          : null
                    : printer.selected == null
                    ? null
                    : () => controller.printTest(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
