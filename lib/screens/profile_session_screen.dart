import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/change_pin_dialog.dart';
import '../widgets/printer_settings.dart';
import '../widgets/cashier_shift_sheet.dart';
import '../widgets/primary_button.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_controls.dart';
import 'user_management_screen.dart';
import 'owner_shifts_screen.dart';

class ProfileSessionScreen extends ConsumerWidget {
  const ProfileSessionScreen({super.key});

  Widget _cashBreakdown(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          CurrencyFormatter.format(amount),
          style: AppNumbers.price.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverCustomAppBar(
            title: 'Profil & Sesi Kasir',
            subtitle: session.shopBranch,
            showSyncBadge: !session.isOnline,
            isOnline: session.isOnline,
            actions: [
              if (user.isAdmin)
                TopBarActionButton(
                  icon: Icons.people_outline,
                  tooltip: 'Kelola Pengguna',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Card (Screen 10 User Info)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryGreen,
                            child: Text(
                              user.name
                                  .split(' ')
                                  .map((e) => e[0])
                                  .take(2)
                                  .join(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${user.username} · ${user.role.label}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${user.staffId} · ${user.gender.label}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  user.branch,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.isShiftActive
                                      ? 'Kas yang diharapkan'
                                      : 'Kas aktual shift terakhir',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              AppBadge(
                                label: session.isShiftActive
                                    ? 'Shift aktif'
                                    : 'Shift ditutup',
                                tone: session.isShiftActive
                                    ? AppBadgeTone.positive
                                    : AppBadgeTone.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(
                                session.isShiftActive
                                    ? session.cashInDrawer
                                    : session
                                              .closedShifts
                                              .firstOrNull
                                              ?.actualCash ??
                                          0,
                              ),
                              style: AppNumbers.total,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1),
                          ),
                          _cashBreakdown('Modal awal', session.startingCapital),
                          const SizedBox(height: 16),
                          _cashBreakdown(
                            'Penjualan tunai',
                            session.cashInDrawer - session.startingCapital,
                          ),
                          const SizedBox(height: 16),
                          _cashBreakdown('Non-tunai', session.nonCashTotal),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hardware & Settings Card (Screen 10 Hardware Settings)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Perangkat Keras & Pengaturan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          const PrinterConnectionTile(),

                          const Divider(
                            height: 16,
                            color: AppColors.dividerColor,
                          ),

                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(
                              Icons.wifi,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                            title: const Text(
                              'Mode Offline-First',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: const Text(
                              'Simpan transaksi lokal saat sinyal drop',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: !session.isOnline,
                            activeTrackColor: AppColors.warningLow,
                            onChanged: (_) => ref
                                .read(sessionProvider.notifier)
                                .toggleOnline(),
                          ),
                          const Divider(
                            height: 16,
                            color: AppColors.dividerColor,
                          ),

                          // Security PIN
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.lock_outline,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                            title: const Text(
                              'Ubah PIN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'PIN untuk masuk pada perangkat ini',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onTap: () async {
                              final changed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const ChangePinDialog(),
                              );
                              if (changed == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('PIN berhasil diubah.'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (session.error != null) ...[
                    Text(
                      session.error!,
                      style: const TextStyle(color: AppColors.alertCritical),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).load(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                  PrimaryButton(
                    text: session.isShiftActive ? 'Tutup Shift' : 'Buka Shift',
                    icon: Icons.point_of_sale_outlined,
                    isLoading: session.loading || session.saving,
                    onPressed: session.error != null
                        ? null
                        : () => showCashierShiftSheet(
                            context,
                            closing: session.activeShift,
                          ),
                  ),
                  if (user.isAdmin)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OwnerShiftsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Kelola Shift · Semua Kasir'),
                    ),
                  if (session.closedShifts.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          showShiftHistory(context, session.closedShifts),
                      icon: const Icon(Icons.history_outlined),
                      label: const Text('Riwayat Shift'),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.alertCritical),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.alertCritical,
                      ),
                      label: const Text(
                        'Keluar Akun (Logout)',
                        style: TextStyle(
                          color: AppColors.alertCritical,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(authProvider.notifier).logout();
                        } on AuthException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
