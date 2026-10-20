import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cashier_shift.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../data/initial_products.dart';
import '../services/product_photo_store.dart';
import '../models/user_profile.dart';
import '../services/auth_store.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

// shortcut: one atomic local snapshot fits this device; use a database for larger catalogs or synchronization.
final shiftStoreProvider = Provider<AuthStore>(
  (ref) => const SecureAuthStore(key: 'exsha.shifts.v1'),
);

class SessionState {
  final UserProfile? currentUser;
  final String shopName, shopBranch;
  final bool isOnline, loading, saving;
  final String? error;
  final List<CashierShift> shifts;
  final List<Product> products;
  const SessionState({
    required this.currentUser,
    this.shopName = 'EX-SHA Bird Shop',
    this.shopBranch = 'Cabang Utama - Pasar Burung Pramuka',
    this.isOnline = true,
    this.loading = false,
    this.saving = false,
    this.error,
    this.shifts = const [],
    this.products = initialProducts,
  });
  CashierShift? get activeShift =>
      shifts.where((s) => s.userId == currentUser?.id && s.isOpen).firstOrNull;
  List<CashierShift> get closedShifts => shifts
      .where((s) => s.userId == currentUser?.id && !s.isOpen)
      .toList()
      .reversed
      .toList();
  CashierShift? get _latest => activeShift ?? closedShifts.firstOrNull;
  bool get isShiftActive => activeShift != null;
  double get startingCapital => _latest?.openingCash ?? 0;
  double get cashInDrawer => _latest?.expectedCash ?? 0;
  double get nonCashTotal => _latest?.nonCashSales ?? 0;
  DateTime get shiftStartTime => _latest?.startedAt.toLocal() ?? DateTime.now();
  SessionState copyWith({
    UserProfile? currentUser,
    bool clearUser = false,
    bool? isOnline,
    bool? loading,
    bool? saving,
    String? error,
    List<CashierShift>? shifts,
    List<Product>? products,
  }) => SessionState(
    currentUser: clearUser ? null : currentUser ?? this.currentUser,
    shopName: shopName,
    shopBranch: shopBranch,
    isOnline: isOnline ?? this.isOnline,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: error,
    shifts: shifts ?? this.shifts,
    products: products ?? this.products,
  );
}

class SessionNotifier extends Notifier<SessionState> {
  bool _loading = false;
  DateTime get _now => ref.read(authClockProvider)().toUtc();
  @override
  SessionState build() {
    ref.listen(authProvider.select((a) => a.currentUser), (_, user) {
      state = state.copyWith(
        currentUser: user,
        clearUser: user == null,
        error: state.error,
      );
    });
    Future.microtask(load);
    return SessionState(
      currentUser: ref.read(authProvider).currentUser,
      loading: true,
    );
  }

  Future<void> load() async {
    if (state.saving || _loading) return;
    _loading = true;
    state = state.copyWith(loading: true);
    try {
      final raw = await ref.read(shiftStoreProvider).read();
      if (!ref.mounted) return;
      final json = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (json != null && ![1, 2].contains(json['schemaVersion'])) {
        throw const FormatException('Unsupported shift data');
      }
      final shifts = json == null
          ? <CashierShift>[]
          : (json['shifts'] as List)
                .map(
                  (s) => CashierShift.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList();
      final openUsers = shifts
          .where((s) => s.isOpen)
          .map((s) => s.userId)
          .toList();
      final saleIds = shifts.expand((s) => s.sales).map((t) => t.id).toList();
      if (shifts.map((s) => s.id).toSet().length != shifts.length ||
          openUsers.toSet().length != openUsers.length ||
          saleIds.toSet().length != saleIds.length) {
        throw const FormatException('Duplicate shift data');
      }
      final products = json?['schemaVersion'] == 2
          ? (json!['products'] as List)
                .map(
                  (p) => Product.fromJson(Map<String, dynamic>.from(p as Map)),
                )
                .toList()
          : initialProducts;
      _validateProducts(products);
      if (json?['schemaVersion'] != 2) {
        await ref.read(shiftStoreProvider).write(_encode(shifts, products));
        if (!ref.mounted) return;
      }
      state = state.copyWith(
        loading: false,
        shifts: shifts,
        products: products,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          loading: false,
          error: 'Data toko tidak dapat dibaca. Coba lagi; data tidak dihapus.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  void _ready() {
    if (state.loading || state.error != null) {
      throw const AuthException('Data toko belum siap. Coba muat ulang.');
    }
    if (state.saving) {
      throw const AuthException('Tunggu penyimpanan data selesai.');
    }
  }

  bool isPreviousDay(CashierShift shift) {
    final start = shift.startedAt.toLocal();
    final now = _now.toLocal();
    return start.year != now.year ||
        start.month != now.month ||
        start.day != now.day;
  }

  CashierShift requireActiveShift() {
    _ready();
    final user = ref.read(authProvider.notifier).requireUser();
    final shift = state.shifts
        .where((s) => s.userId == user.id && s.isOpen)
        .firstOrNull;
    if (shift == null) {
      throw const AuthException(
        'Buka shift terlebih dahulu sebelum bertransaksi.',
      );
    }
    if (_now.isBefore(shift.startedAt)) {
      throw const AuthException(
        'Waktu perangkat tidak sesuai waktu buka shift.',
      );
    }
    if (isPreviousDay(shift)) {
      throw const AuthException(
        'Tutup shift sebelumnya sebelum memulai transaksi baru.',
      );
    }
    return shift;
  }

  void _amount(double value) {
    if (!value.isFinite || value < 0 || value > 999999999999) {
      throw const AuthException(
        'Masukkan nominal yang valid dan tidak negatif.',
      );
    }
  }

  String _encode(List<CashierShift> shifts, List<Product> products) =>
      jsonEncode({
        'schemaVersion': 2,
        'shifts': shifts.map((s) => s.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
      });

  void _validateProducts(List<Product> products) {
    if (products.map((p) => p.sku.toLowerCase()).toSet().length !=
            products.length ||
        products.any(
          (p) =>
              p.sku.trim().isEmpty ||
              p.name.trim().isEmpty ||
              p.category.trim().isEmpty ||
              !p.price.isFinite ||
              p.price < 0 ||
              p.price > 999999999999 ||
              p.stock < 0 ||
              p.stock > 999999999 ||
              p.minStock < 0 ||
              p.minStock > 999999999,
        )) {
      throw const AuthException(
        'Data produk tidak valid. Periksa SKU, harga dan stok.',
      );
    }
  }

  Future<void> _save(
    List<CashierShift> shifts, {
    List<Product>? products,
  }) async {
    final catalog = products ?? state.products;
    state = state.copyWith(saving: true);
    try {
      await ref.read(shiftStoreProvider).write(_encode(shifts, catalog));
      if (ref.mounted) {
        state = state.copyWith(
          saving: false,
          shifts: shifts,
          products: catalog,
        );
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(saving: false);
      throw const AuthException(
        'Data gagal disimpan. Data sebelumnya tetap tersedia. Coba lagi.',
      );
    }
  }

  Future<void> saveProduct(Product product, {bool isNew = false}) async {
    _ready();
    ref.read(authProvider.notifier).requireAdmin();
    final exists = state.products.any(
      (p) => p.sku.toLowerCase() == product.sku.toLowerCase(),
    );
    if (isNew == exists) {
      throw AuthException(
        isNew ? 'SKU sudah digunakan.' : 'Produk tidak ditemukan.',
      );
    }
    final products = isNew
        ? [product, ...state.products]
        : [for (final p in state.products) p.sku == product.sku ? product : p];
    _validateProducts(products);
    state = state.copyWith(saving: true);
    try {
      final path = await ref
          .read(productPhotoStoreProvider)
          .persist(product.imageUrl);
      await _save(
        state.shifts,
        products: [
          for (final p in products)
            p.sku == product.sku ? p.copyWith(imageUrl: path) : p,
        ],
      );
    } catch (e) {
      if (ref.mounted) state = state.copyWith(saving: false);
      if (e is AuthException) rethrow;
      throw const AuthException('Foto atau produk gagal disimpan. Coba lagi.');
    }
  }

  Future<void> deleteProduct(String sku) async {
    _ready();
    ref.read(authProvider.notifier).requireAdmin();
    if (!state.products.any((p) => p.sku == sku)) {
      throw const AuthException('Produk tidak ditemukan.');
    }
    await _save(
      state.shifts,
      products: state.products.where((p) => p.sku != sku).toList(),
    );
  }

  Future<void> updateStock(String sku, int quantity) async {
    _ready();
    ref.read(authProvider.notifier).requireAdmin();
    final product = state.products.where((p) => p.sku == sku).firstOrNull;
    if (product == null) throw const AuthException('Produk tidak ditemukan.');
    final products = [
      for (final p in state.products)
        p.sku == sku ? p.copyWith(stock: quantity) : p,
    ];
    _validateProducts(products);
    await _save(state.shifts, products: products);
  }

  Future<CashierShift> openNewShift(double initialCash) async {
    _ready();
    final user = ref.read(authProvider.notifier).requireUser();
    _amount(initialCash);
    if (state.shifts.any((s) => s.userId == user.id && s.isOpen)) {
      throw const AuthException(
        'Shift Anda masih aktif. Tutup shift tersebut terlebih dahulu.',
      );
    }
    final now = _now;
    final shift = CashierShift(
      id: 'SHF-${now.microsecondsSinceEpoch}-${state.shifts.length + 1}',
      userId: user.id,
      cashierName: user.name,
      startedAt: now,
      openingCash: initialCash,
    );
    await _save([...state.shifts, shift]);
    return shift;
  }

  Future<void> recordSale(TransactionRecord sale) async {
    final shift = requireActiveShift();
    _amount(sale.totalAmount);
    if (sale.cashierId != shift.userId ||
        sale.timestamp.isBefore(shift.startedAt) ||
        sale.shiftId != shift.id ||
        state.shifts.expand((s) => s.sales).any((t) => t.id == sale.id)) {
      throw const AuthException(
        'Transaksi tidak sesuai shift atau sudah tersimpan.',
      );
    }
    final quantities = {
      for (final item in sale.items) item.product.sku: item.quantity,
    };
    if (sale.items.isEmpty || quantities.length != sale.items.length) {
      throw const AuthException('Keranjang tidak valid.');
    }
    for (final item in sale.items) {
      final product = state.products
          .where((p) => p.sku == item.product.sku)
          .firstOrNull;
      if (product == null ||
          item.quantity <= 0 ||
          item.quantity > product.stock) {
        throw const AuthException('Stok berubah. Periksa kembali keranjang.');
      }
      if (product.price != item.product.price) {
        throw const AuthException(
          'Harga berubah. Tambahkan ulang produk ke keranjang.',
        );
      }
    }
    final updated = shift.copyWith(sales: [...shift.sales, sale]);
    await _save(
      [for (final s in state.shifts) s.id == shift.id ? updated : s],
      products: [
        for (final p in state.products)
          p.copyWith(stock: p.stock - (quantities[p.sku] ?? 0)),
      ],
    );
  }

  Future<CashierShift> closeShift(
    double actualCash, {
    String note = '',
    String? shiftId,
  }) async {
    _ready();
    final user = ref.read(authProvider.notifier).requireUser();
    final shift = state.shifts
        .where((s) => s.userId == user.id && s.isOpen)
        .firstOrNull;
    if (shift == null) {
      throw const AuthException('Tidak ada shift aktif untuk ditutup.');
    }
    if (shiftId != null && shift.id != shiftId) {
      throw const AuthException(
        'Shift telah berubah. Buka kembali ringkasan shift.',
      );
    }
    _amount(actualCash);
    if (ref.read(cartProvider).items.isNotEmpty) {
      throw const AuthException(
        'Selesaikan atau kosongkan keranjang sebelum menutup shift.',
      );
    }
    if ((actualCash - shift.expectedCash).abs() >= .005 &&
        note.trim().isEmpty) {
      throw const AuthException('Isi catatan untuk menjelaskan selisih kas.');
    }
    if (note.trim().length > 500) {
      throw const AuthException('Catatan maksimal 500 karakter.');
    }
    final closed = shift.copyWith(
      closedAt: _now,
      actualCash: actualCash,
      note: note.trim(),
    );
    if (closed.closedAt!.isBefore(shift.startedAt)) {
      throw const AuthException(
        'Waktu perangkat tidak sesuai waktu buka shift.',
      );
    }
    await _save([for (final s in state.shifts) s.id == shift.id ? closed : s]);
    if (ref.read(authProvider).currentUser?.id == user.id) {
      ref.invalidate(cartProvider);
    }
    return closed;
  }

  void toggleOnline() {
    ref.read(authProvider.notifier).requireUser();
    state = state.copyWith(isOnline: !state.isOnline, error: state.error);
  }

  void checkDay() => state = state.copyWith(error: state.error);
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
