import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/cashier_shift_gate.dart';
import '../widgets/store_data_gate.dart';
import 'inventory_screen.dart';
import 'pos_cashier_screen.dart';
import 'profile_session_screen.dart';
import 'sales_report_screen.dart';
import 'transaction_history_screen.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static const List<Widget> _screens = [
    StoreDataGate(child: CashierShiftGate(child: PosCashierScreen())),
    StoreDataGate(child: InventoryScreen()),
    TransactionHistoryScreen(),
    SalesReportScreen(),
    ProfileSessionScreen(),
  ];

  static const List<int> _navDestinationToScreenIndex = [0, 1, 2, 3, 4];
  static const List<NavigationDestination> _bottomDestinations = [
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: 'Kasir',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Produk',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Riwayat',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Laporan',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Akun',
    ),
  ];

  static const List<NavigationRailDestination> _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: Text('Kasir'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: Text('Produk'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text('Riwayat'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: Text('Laporan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: Text('Akun'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainNavIndexProvider);
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const SizedBox.shrink();
    final allowed = user.isAdmin
        ? _navDestinationToScreenIndex
        : const [0, 2, 4];
    final navIndex = allowed.contains(currentIndex)
        ? allowed.indexOf(currentIndex)
        : 0;

    final isExpanded = MediaQuery.sizeOf(context).width >= 600;
    void selectDestination(int destinationIndex) {
      ref
          .read(mainNavIndexProvider.notifier)
          .setIndex(allowed[destinationIndex]);
    }

    return Scaffold(
      body: Row(
        children: [
          if (isExpanded)
            NavigationRail(
              selectedIndex: navIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: selectDestination,
              destinations: [for (final i in allowed) _railDestinations[i]],
            ),
          Expanded(
            child: IndexedStack(
              index: navIndex,
              children: [for (final i in allowed) _screens[i]],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isExpanded
          ? null
          : NavigationBar(
              selectedIndex: navIndex,
              onDestinationSelected: selectDestination,
              destinations: [for (final i in allowed) _bottomDestinations[i]],
            ),
    );
  }
}
