import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:birdshop_posapp/models/product.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/services/product_photo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';
import 'cashier_shift_test.dart' show sell;

class SlowStore extends MemoryAuthStore {
  Completer<void>? gate;
  @override
  Future<void> write(String value) async {
    await gate?.future;
    await super.write(value);
  }
}

const product = Product(
  sku: 'NEW-01',
  name: 'Pakan Baru',
  category: 'Pakan & Voer',
  price: 25000,
  stock: 20,
  minStock: 4,
  imageUrl: '',
  tags: ['500g'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryAuthStore accounts, ledger;
  late ProviderContainer c;
  setUp(() async {
    accounts = MemoryAuthStore();
    ledger = MemoryAuthStore();
    c = authContainer(accounts, shifts: ledger);
    addTearDown(c.dispose);
    await awaitAuthLoaded(c);
    await c.read(authProvider.notifier).setupOwner('Owner', 'owner', '654321');
    await c
        .read(authProvider.notifier)
        .login('owner', '654321', keepLoggedIn: true);
  });

  Future<ProviderContainer> restart() async {
    final next = authContainer(accounts, shifts: ledger);
    addTearDown(next.dispose);
    await awaitAuthLoaded(next);
    return next;
  }

  test('catalog creation, edits, stock, tags, deletions and empty catalog survive restart', () async {
    final inventory = c.read(inventoryProvider.notifier);
    await inventory.addProduct(product);
    await inventory.updateProduct(
      product.copyWith(name: 'Pakan Premium', price: 30000, minStock: 6),
    );
    await inventory.updateStock(product.sku, 27);
    final next = await restart();
    final restored = next.read(inventoryProvider).products.first;
    expect(restored.name, 'Pakan Premium');
    expect(restored.price, 30000);
    expect(restored.stock, 27);
    expect(restored.minStock, 6);
    expect(restored.tags, ['500g']);
    for (final p in next.read(inventoryProvider).products.toList()) {
      await next.read(inventoryProvider.notifier).deleteProduct(p.sku);
    }
    expect((await restart()).read(inventoryProvider).products, isEmpty);
  });

  test('sale and stock persist in the same write and are not deducted again on restart', () async {
    await c.read(sessionProvider.notifier).openNewShift(100000);
    final before = c.read(inventoryProvider).products.first.stock;
    final sale = await sell(c, PaymentMethod.tunai);
    final saved = jsonDecode(ledger.value!) as Map;
    expect((saved['products'] as List).first['stock'], before - 1);
    expect(saved['shifts'][0]['sales'][0]['id'], sale.id);
    final next = await restart();
    expect(next.read(inventoryProvider).products.first.stock, before - 1);
    expect(next.read(sessionProvider).activeShift!.sales.single.id, sale.id);
    await next.read(sessionProvider.notifier).load();
    expect(next.read(inventoryProvider).products.first.stock, before - 1);
  });

  test(
    'failed create, edit, delete and sale preserve durable and visible data',
    () async {
      final inventory = c.read(inventoryProvider.notifier);
      await c.read(sessionProvider.notifier).openNewShift(0);
      final saved = ledger.value;
      final original = c.read(inventoryProvider).products.first;
      ledger.failWrites = true;
      for (final operation in <Future<void> Function()>[
        () => inventory.addProduct(product),
        () => inventory.updateProduct(original.copyWith(name: 'Changed')),
        () => inventory.deleteProduct(original.sku),
        () => inventory.updateStock(original.sku, 1),
        () async {
          await sell(c, PaymentMethod.tunai);
        },
      ]) {
        await expectLater(operation(), throwsA(isA<AuthException>()));
        expect(ledger.value, saved);
        expect(c.read(inventoryProvider).products.first.name, original.name);
        expect(c.read(inventoryProvider).products.first.stock, original.stock);
        expect(c.read(sessionProvider).saving, isFalse);
      }
    },
  );

  test(
    'invalid or duplicate catalog values are rejected before writing',
    () async {
      final inventory = c.read(inventoryProvider.notifier);
      await inventory.addProduct(product);
      final saved = ledger.value;
      for (final invalid in [
        product.copyWith(stock: -1),
        product.copyWith(price: double.nan),
        product.copyWith(minStock: -1),
        product.copyWith(name: ''),
      ]) {
        await expectLater(
          inventory.updateProduct(invalid),
          throwsA(isA<AuthException>()),
        );
      }
      await expectLater(
        inventory.addProduct(product.copyWith(sku: 'new-01')),
        throwsA(isA<AuthException>()),
      );
      expect(ledger.value, saved);
    },
  );

  test(
    'legacy shift ledger migrates once without changing saved shift records',
    () async {
      await c.read(sessionProvider.notifier).openNewShift(12345);
      final previous = jsonDecode(ledger.value!) as Map<String, dynamic>;
      previous.remove('products');
      previous['schemaVersion'] = 1;
      ledger.value = jsonEncode(previous);
      final next = await restart();
      expect(next.read(sessionProvider).activeShift!.openingCash, 12345);
      expect(next.read(inventoryProvider).products, isNotEmpty);
      expect(jsonDecode(ledger.value!)['schemaVersion'], 2);
      expect(jsonDecode(ledger.value!)['shifts'], previous['shifts']);
    },
  );

  test('corrupt catalog and failed migration block operations without replacing saved data', () async {
    final broken = jsonDecode(ledger.value!) as Map<String, dynamic>;
    broken['products'][0]['stock'] = -1;
    ledger.value = jsonEncode(broken);
    final next = await restart();
    expect(next.read(sessionProvider).error, isNotNull);
    final raw = ledger.value;
    await expectLater(
      next.read(inventoryProvider.notifier).addProduct(product),
      throwsA(isA<AuthException>()),
    );
    expect(ledger.value, raw);
    ledger.value = '{"schemaVersion":1,"shifts":[]}';
    ledger.failWrites = true;
    await next.read(sessionProvider.notifier).load();
    expect(next.read(sessionProvider).error, isNotNull);
    expect(ledger.value, '{"schemaVersion":1,"shifts":[]}');
  });

  test(
    'pending catalog save prevents sales, closes, and conflicting edits',
    () async {
      final slow = SlowStore();
      final next = authContainer(accounts, shifts: slow);
      addTearDown(next.dispose);
      await awaitAuthLoaded(next);
      await next.read(sessionProvider.notifier).openNewShift(0);
      slow.gate = Completer<void>();
      final pending = next.read(inventoryProvider.notifier).addProduct(product);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        sell(next, PaymentMethod.tunai),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        next.read(inventoryProvider.notifier).deleteProduct(product.sku),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        next.read(sessionProvider.notifier).closeShift(0),
        throwsA(isA<AuthException>()),
      );
      slow.gate!.complete();
      await pending;
      expect(next.read(inventoryProvider).products.first.sku, product.sku);
    },
  );

  test(
    'selected photo is copied outside picker cache and survives cache removal',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'inventory-photo-test',
      );
      addTearDown(() => temp.delete(recursive: true));
      final cache = await Directory('${temp.path}/cache').create();
      final support = await Directory('${temp.path}/support').create();
      final original = File('${cache.path}/picked.jpg');
      await original.writeAsBytes([1, 2, 3, 4]);
      final photos = ProductPhotoStore(directory: () async => support);
      final next = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(ledger),
          productPhotoStoreProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(next.dispose);
      await awaitAuthLoaded(next);
      await next
          .read(inventoryProvider.notifier)
          .addProduct(product.copyWith(imageUrl: original.path));
      await cache.delete(recursive: true);
      final storedPath = next.read(inventoryProvider).products.first.imageUrl;
      expect(storedPath, startsWith(support.path));
      expect(await File(storedPath).readAsBytes(), [1, 2, 3, 4]);
      expect(await photos.persist(storedPath), storedPath);
      final restored = await restart();
      expect(
        restored.read(inventoryProvider).products.first.imageUrl,
        storedPath,
      );
    },
  );
}
