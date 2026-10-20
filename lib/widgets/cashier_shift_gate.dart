import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'custom_app_bar.dart';
import 'primary_button.dart';
import 'cashier_shift_sheet.dart';

class CashierShiftGate extends ConsumerWidget {
  final Widget child;
  const CashierShiftGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.currentUser?.isAdmin == true) return child;
    final controller = ref.read(sessionProvider.notifier);
    final active = session.activeShift;
    if (!session.loading &&
        session.error == null &&
        active != null &&
        !controller.isPreviousDay(active)) {
      return child;
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: CustomAppBar(
        title: 'Shift Kasir',
        subtitle: session.currentUser?.name ?? '',
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.point_of_sale_outlined,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    session.loading
                        ? 'Memuat shift…'
                        : session.error != null
                        ? 'Shift belum tersedia'
                        : active != null
                        ? 'Tutup shift sebelumnya'
                        : 'Siap mulai shift?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.error ??
                        (active != null
                            ? 'Shift dari hari sebelumnya masih terbuka. Hitung kas dan tutup shift tersebut sebelum melayani transaksi baru.'
                            : 'Buka shift dan catat modal awal kas sebelum mulai bertransaksi.'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    text: session.error != null
                        ? 'Coba Lagi'
                        : active != null
                        ? 'Tutup Shift Sebelumnya'
                        : 'Buka Shift',
                    isLoading: session.loading || session.saving,
                    onPressed: session.error != null
                        ? controller.load
                        : () => showCashierShiftSheet(context, closing: active),
                  ),
                  if (session.closedShifts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          showShiftHistory(context, session.closedShifts),
                      child: const Text('Riwayat Shift'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
