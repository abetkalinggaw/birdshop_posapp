import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/providers/transaction_provider.dart';
import 'package:birdshop_posapp/services/auth_store.dart';

import 'auth_test_support.dart';

void main() {
  test('Staff IDs encode role, gender and global serial without dots', () {
    expect(
      UserProfile.formatStaffId(UserRole.admin, StaffGender.male, 1),
      'ADM-10001',
    );
    expect(
      UserProfile.formatStaffId(UserRole.cashier, StaffGender.female, 2),
      'CSH-20002',
    );
    expect(
      UserProfile.formatStaffId(UserRole.cashier, StaffGender.unspecified, 3),
      'CSH-00003',
    );
    expect(
      UserProfile.formatStaffId(UserRole.admin, StaffGender.other, 10000),
      'ADM-310000',
    );
  });

  test('serial increments across roles, survives restart and is not consumed on save failure', () async {
    final store = MemoryAuthStore();
    final container = authContainer(store);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner(
      'Owner',
      'abet.owner',
      '654321',
      gender: StaffGender.male,
    );
    expect(container.read(authProvider).users.single.staffId, 'ADM-10001');
    await auth.login('ABET.OWNER', '654321');
    store.failWrites = true;
    await expectLater(
      auth.addUser(
        'Cashier',
        'bayu',
        '123456',
        UserRole.cashier,
        '',
        gender: StaffGender.female,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(auth.nextSerial, 2);
    expect(container.read(authProvider).users.length, 1);
    store.failWrites = false;
    await auth.addUser(
      'Cashier',
      'bayu',
      '123456',
      UserRole.cashier,
      '',
      gender: StaffGender.female,
    );
    expect(container.read(authProvider).users.last.staffId, 'CSH-20002');
    final restored = authContainer(store);
    addTearDown(restored.dispose);
    await awaitAuthLoaded(restored);
    final next = restored.read(authProvider.notifier);
    await next.login('abet.owner', '654321');
    await next.addUser(
      'Admin',
      'ratna',
      '222222',
      UserRole.admin,
      '',
      gender: StaffGender.female,
    );
    expect(restored.read(authProvider).users.last.staffId, 'ADM-20003');
    expect(next.nextSerial, 4);
  });

  test('generated Staff ID cannot authenticate and username uniqueness is case insensitive', () async {
    final container = authContainer(MemoryAuthStore());
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner(
      'Owner',
      'abet.owner',
      '654321',
      gender: StaffGender.male,
    );
    await expectLater(
      auth.login('ADM-10001', '654321'),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authProvider).currentUser, isNull);
    await auth.login(' ABET.OWNER ', '654321');
    await expectLater(
      auth.addUser('Duplicate', ' Abet.Owner ', '123456', UserRole.cashier, ''),
      throwsA(isA<AuthException>()),
    );
    await auth.addUser('Employee', 'bayu', '123456', UserRole.cashier, '');
    await expectLater(
      auth.updateUser(
        accountId(container, 'bayu'),
        UserRole.cashier,
        username: 'ABET.OWNER',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authProvider).users.last.username, 'bayu');
  });

  test('username, role and gender edits retain serial, PIN, transactions and shifts', () async {
    final container = authContainer(MemoryAuthStore());
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner('Owner', 'owner', '654321', gender: StaffGender.male);
    await auth.login('owner', '654321');
    await auth.addUser(
      'Cashier',
      'bayu',
      '123456',
      UserRole.cashier,
      '',
      gender: StaffGender.male,
    );
    final key = accountId(container, 'bayu');
    await auth.logout();
    await auth.login('bayu', '123456');
    final template = container.read(transactionProvider).transactions.first;
    await container.read(sessionProvider.notifier).openNewShift(10000);
    await container
        .read(transactionProvider.notifier)
        .createTransaction(
          items: [template.items.first],
          subtotal: template.items.first.subtotal,
          memberDiscount: 0,
          tax: 0,
          totalAmount: template.items.first.subtotal,
          paymentMethod: template.paymentMethod,
          receivedAmount: template.items.first.subtotal,
          changeAmount: 0,
          cashierName: 'Cashier',
          cashierId: key,
        );
    await auth.logout();
    await auth.login('owner', '654321');
    await auth.updateUser(
      key,
      UserRole.cashier,
      username: ' Bayu.New ',
      gender: StaffGender.female,
    );
    final updated = container.read(authProvider).users.last;
    expect(updated.id, key);
    expect(updated.cashierCode, key);
    expect(updated.serialNumber, 2);
    expect(updated.staffId, 'CSH-20002');
    await auth.logout();
    await expectLater(
      auth.login('bayu', '123456'),
      throwsA(isA<AuthException>()),
    );
    await auth.login('bayu.new', '123456');
    expect(container.read(visibleTransactionsProvider).single.cashierId, key);
    expect(
      container.read(sessionProvider).cashInDrawer,
      10000 + template.items.first.subtotal,
    );
    await auth.logout();
    await auth.login('owner', '654321');
    await auth.updateUser(key, UserRole.admin);
    expect(container.read(authProvider).users.last.staffId, 'ADM-20002');
    expect(container.read(authProvider).users.last.serialNumber, 2);
    await auth.logout();
    await auth.login('bayu.new', '123456');
    expect(container.read(authProvider).currentUser!.isAdmin, isTrue);
  });

  test('legacy accounts migrate once without changing PINs or historical cashier keys', () async {
    final credential = await const PinHasher(iterations: 1000).hash('654321');
    final legacy = {
      'users': [
        {
          'id': 'OWNER-01',
          'name': 'Existing Owner',
          'role': 'admin',
          'cashierCode': 'OWNER-01',
          'branch': 'Pramuka',
          'phone': '08123',
          'isActive': true,
        },
      ],
      'credentials': {'OWNER-01': credential},
      'failedAttempts': 4,
      'lockedUntil': null,
    };
    final store = MemoryAuthStore()..value = jsonEncode(legacy);
    final container = authContainer(store);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final user = container.read(authProvider).users.single;
    expect(user.id, 'OWNER-01');
    expect(user.username, 'owner-01');
    expect(user.cashierCode, 'OWNER-01');
    expect(user.staffId, 'ADM-00001');
    expect(user.gender, StaffGender.unspecified);
    final saved = jsonDecode(store.value!) as Map<String, dynamic>;
    expect(saved['schemaVersion'], 2);
    expect(saved['lastSerial'], 1);
    expect(saved['failedAttempts'], 4);
    expect(saved['credentials'], legacy['credentials']);
    await container.read(authProvider.notifier).login('OWNER-01', '654321');
    final restored = authContainer(store);
    addTearDown(restored.dispose);
    await awaitAuthLoaded(restored);
    expect(restored.read(authProvider).users.single.serialNumber, 1);
    expect(restored.read(authProvider.notifier).nextSerial, 2);
    await restored.read(authProvider.notifier).login('owner-01', '654321');
  });

  test('failed migration keeps the original data and retries without changing serial allocation', () async {
    final credential = await const PinHasher(iterations: 1000).hash('654321');
    final original = jsonEncode({
      'users': [
        {
          'id': 'OWNER-01',
          'name': 'Owner',
          'role': 'admin',
          'cashierCode': 'OWNER-01',
          'branch': 'Pramuka',
          'phone': '',
          'isActive': true,
        },
      ],
      'credentials': {'OWNER-01': credential},
    });
    final store = MemoryAuthStore()
      ..value = original
      ..failWrites = true;
    final container = authContainer(store);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    expect(container.read(authProvider).storageError, isNotNull);
    expect(container.read(authProvider).needsSetup, isFalse);
    expect(store.value, original);
    store.failWrites = false;
    await container.read(authProvider.notifier).load();
    expect(container.read(authProvider).users.single.serialNumber, 1);
    expect(container.read(authProvider.notifier).nextSerial, 2);
  });

  test('saved counter preserves gaps and prevents serial reuse', () async {
    final store = MemoryAuthStore();
    final initial = authContainer(store);
    addTearDown(initial.dispose);
    await awaitAuthLoaded(initial);
    await initial
        .read(authProvider.notifier)
        .setupOwner('Owner', 'owner', '654321', gender: StaffGender.male);
    final saved = jsonDecode(store.value!) as Map<String, dynamic>;
    saved['lastSerial'] = 9;
    store.value = jsonEncode(saved);
    final restored = authContainer(store);
    addTearDown(restored.dispose);
    await awaitAuthLoaded(restored);
    final auth = restored.read(authProvider.notifier);
    await auth.login('owner', '654321');
    await auth.addUser(
      'Cashier',
      'bayu',
      '123456',
      UserRole.cashier,
      '',
      gender: StaffGender.male,
    );
    expect(restored.read(authProvider).users.last.staffId, 'CSH-10010');
  });
}
