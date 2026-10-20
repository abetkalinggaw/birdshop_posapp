import 'package:birdshop_posapp/providers/session_provider.dart';

import 'auth_test_support.dart';

import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/screens/cart_checkout_screen.dart';
import 'package:birdshop_posapp/screens/inventory_screen.dart';
import 'package:birdshop_posapp/screens/payment_confirmation_screen.dart';
import 'package:birdshop_posapp/screens/payment_method_screen.dart';
import 'package:birdshop_posapp/screens/pos_cashier_screen.dart';
import 'package:birdshop_posapp/screens/profile_session_screen.dart';
import 'package:birdshop_posapp/screens/sales_report_screen.dart';
import 'package:birdshop_posapp/screens/transaction_history_screen.dart';
import 'package:birdshop_posapp/screens/transaction_success_screen.dart';
import 'package:birdshop_posapp/screens/user_management_screen.dart';
import 'package:birdshop_posapp/widgets/custom_app_bar.dart';

void main() {
  group(
    'Consistency of Layout, Design, and Scroll Behaviour across all screens',
    () {
      testWidgets(
        'POS Cashier Screen uses CustomScrollView, floating snap SliverAppBar, and ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: PosCashierScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsOneWidget);
          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Inventory Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: InventoryScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);

          // Verify search pill and no barcode scanner icon
          expect(find.byIcon(Icons.search_rounded), findsOneWidget);
          expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
          expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
        },
      );

      testWidgets(
        'Transaction History Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: TransactionHistoryScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Sales Report Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: SalesReportScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Profile & Session Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: ProfileSessionScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'User Management Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: UserManagementScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Cart Checkout Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: CartCheckoutScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Payment Method Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(home: PaymentMethodScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Payment Confirmation Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(
                home: PaymentConfirmationScreen(
                  trxId: '#TRX-TEST-001',
                  paymentMethod: PaymentMethod.tunai,
                  receivedAmount: 100000,
                  changeAmount: 0,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );

      testWidgets(
        'Transaction Success Screen uses CustomScrollView and SliverCustomAppBar without ScreenContextBar',
        (tester) async {
          final sampleTx = TransactionRecord(
            id: '#TRX-TEST-001',
            timestamp: DateTime.now(),
            items: [],
            subtotal: 50000,
            memberDiscount: 0,
            tax: 5500,
            totalAmount: 55500,
            paymentMethod: PaymentMethod.tunai,
            receivedAmount: 60000,
            changeAmount: 4500,
            cashierName: 'Bayu Pratama',
            cashierId: '#KSR-01',
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(SignedInOwner.new),
                shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
              ],
              child: MaterialApp(
                home: TransactionSuccessScreen(transaction: sampleTx),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(SliverCustomAppBar), findsOneWidget);
          expect(find.byType(ScreenContextBar), findsNothing);

          final sliverAppBar = tester.widget<SliverAppBar>(
            find.byType(SliverAppBar),
          );
          expect(sliverAppBar.floating, isTrue);
          expect(sliverAppBar.snap, isTrue);
          expect(sliverAppBar.pinned, isFalse);
        },
      );
    },
  );
}
