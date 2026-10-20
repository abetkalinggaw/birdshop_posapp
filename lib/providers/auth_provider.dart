import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/auth_store.dart';
import 'cart_provider.dart';
import 'navigation_provider.dart';

final authStoreProvider = Provider<AuthStore>((ref) => SecureAuthStore());
final pinHasherProvider = Provider<PinHasher>((ref) => const PinHasher());
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class _LoginSession {
  final String userId;
  final DateTime startedAt;
  final DateTime? expiresAt;
  const _LoginSession(this.userId, this.startedAt, this.expiresAt);

  bool isValidAt(DateTime now) =>
      !now.isBefore(startedAt) &&
      (expiresAt == null || now.isBefore(expiresAt!));

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'startedAt': startedAt.toIso8601String(),
    'keepLoggedIn': expiresAt == null,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  static _LoginSession? fromJson(dynamic value) {
    if (value == null) return null;
    try {
      final json = value as Map;
      final startedAt = DateTime.parse(json['startedAt'] as String);
      final keep = json['keepLoggedIn'] as bool;
      final expiresAt = keep
          ? null
          : DateTime.parse(json['expiresAt'] as String);
      if ((keep && json['expiresAt'] != null) ||
          (expiresAt != null &&
              expiresAt.difference(startedAt) != const Duration(hours: 8))) {
        return null;
      }
      return _LoginSession(json['userId'] as String, startedAt, expiresAt);
    } catch (_) {
      return null;
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthState {
  final bool loading;
  final String? storageError;
  final List<UserProfile> users;
  final UserProfile? currentUser;
  final String? loginNotice;
  const AuthState({
    this.loading = false,
    this.storageError,
    this.users = const [],
    this.currentUser,
    this.loginNotice,
  });
  bool get needsSetup => !loading && storageError == null && users.isEmpty;
}

class AuthNotifier extends Notifier<AuthState> {
  Map<String, Map<String, dynamic>> _credentials = {};
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  bool _busy = false;
  int _sessionGeneration = 0;
  int _lastSerial = 0;
  _LoginSession? _session;
  Timer? _sessionTimer;

  DateTime get _now => ref.read(authClockProvider)().toUtc();

  int get nextSerial => _lastSerial + 1;

  @override
  AuthState build() {
    ref.onDispose(() => _sessionTimer?.cancel());
    Future.microtask(load);
    return const AuthState(loading: true);
  }

  Future<void> load() async {
    _sessionGeneration++;
    _sessionTimer?.cancel();
    _session = null;
    state = const AuthState(loading: true);
    try {
      final raw = await ref.read(authStoreProvider).read();
      if (raw == null) {
        state = const AuthState();
        return;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final version = json['schemaVersion'] as int? ?? 1;
      if (version != 1 && version != 2) {
        throw const FormatException('Unsupported account schema');
      }
      _credentials = (json['credentials'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
      _failedAttempts = json['failedAttempts'] as int? ?? 0;
      _lockedUntil = DateTime.tryParse(json['lockedUntil'] as String? ?? '');
      final rows = (json['users'] as List)
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList();
      _lastSerial = json['lastSerial'] as int? ?? 0;
      for (final row in rows) {
        final serial = row['serialNumber'] as int? ?? 0;
        if (serial > _lastSerial) _lastSerial = serial;
      }
      // Preserve existing credential keys and transaction attribution. The old
      // login ID becomes a username; new display IDs never authenticate users.
      if (version == 1) {
        for (final row in rows) {
          row['username'] = normalizeUsername(row['id'] as String);
          row['gender'] = StaffGender.unspecified.name;
          row['serialNumber'] = ++_lastSerial;
        }
      }
      final users = rows.map(UserProfile.fromJson).toList();
      if (users.isEmpty ||
          !users.any((u) => u.isAdmin && u.isActive) ||
          users.any(
            (u) =>
                !_credentials.containsKey(u.id) ||
                u.serialNumber < 1 ||
                u.username != normalizeUsername(u.username),
          ) ||
          users.map((u) => u.id).toSet().length != users.length ||
          users.map((u) => u.username).toSet().length != users.length ||
          users.map((u) => u.serialNumber).toSet().length != users.length) {
        throw const FormatException('Invalid staff data');
      }
      for (final user in users) {
        validateUsername(user.username);
      }
      if (version == 1) {
        await _save(users, _credentials);
      }
      final savedSession = _LoginSession.fromJson(json['session']);
      final restored = savedSession == null
          ? null
          : users
                .where((u) => u.id == savedSession.userId && u.isActive)
                .firstOrNull;
      final valid = restored != null && savedSession!.isValidAt(_now);
      _session = valid ? savedSession : null;
      state = AuthState(
        users: users,
        currentUser: valid ? restored : null,
        loginNotice: json['session'] != null && !valid
            ? 'Sesi berakhir. Masuk kembali untuk melanjutkan.'
            : null,
      );
      _scheduleExpiry();
    } catch (_) {
      state = const AuthState(
        storageError: 'Akun pada perangkat ini tidak dapat dibaca. Coba lagi; data akun tidak dihapus.',
      );
    }
  }

  Future<void> _save(
    List<UserProfile> users,
    Map<String, Map<String, dynamic>> credentials, {
    int? lastSerial,
    bool clearSession = false,
  }) async {
    try {
      await ref
          .read(authStoreProvider)
          .write(
            jsonEncode({
              'schemaVersion': 2,
              'lastSerial': lastSerial ?? _lastSerial,
              'users': users.map((u) => u.toJson()).toList(),
              'credentials': credentials,
              'failedAttempts': _failedAttempts,
              'lockedUntil': _lockedUntil?.toIso8601String(),
              'session': clearSession ? null : _session?.toJson(),
            }),
          );
    } catch (_) {
      throw const AuthException('Akun gagal disimpan. Coba lagi.');
    }
    _credentials = credentials;
    if (lastSerial != null) _lastSerial = lastSerial;
  }

  Future<void> _exclusive(Future<void> Function() action) async {
    if (_busy) throw const AuthException('Tunggu proses sebelumnya selesai.');
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  void requireAdmin() {
    if (!requireUser().isAdmin) {
      throw const AuthException('Hanya Admin yang dapat mengelola data ini.');
    }
  }

  UserProfile requireUser() {
    checkSession();
    final user = state.currentUser;
    if (user == null || !user.isActive) {
      throw const AuthException('Silakan masuk terlebih dahulu.');
    }
    return user;
  }

  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();
  static void validateUsername(String username) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_.-]{2,23}$').hasMatch(username)) {
      throw const AuthException(
        'Username: 3–24 huruf, angka, titik, tanda - atau _.',
      );
    }
  }

  static void validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const AuthException('PIN harus terdiri dari 6 angka.');
    }
  }

  Future<void> setupOwner(
    String name,
    String username,
    String pin, {
    StaffGender gender = StaffGender.unspecified,
  }) => _exclusive(() async {
    if (!state.needsSetup) {
      throw const AuthException('Akun Owner sudah tersedia.');
    }
    await _create(
      name,
      username,
      pin,
      UserRole.admin,
      '',
      gender: gender,
      setup: true,
    );
  });

  Future<void> addUser(
    String name,
    String username,
    String pin,
    UserRole role,
    String phone, {
    StaffGender gender = StaffGender.unspecified,
  }) => _exclusive(() async {
    requireAdmin();
    await _create(name, username, pin, role, phone, gender: gender);
  });

  Future<void> _create(
    String name,
    String username,
    String pin,
    UserRole role,
    String phone, {
    required StaffGender gender,
    bool setup = false,
  }) async {
    username = normalizeUsername(username);
    if (name.trim().isEmpty) throw const AuthException('Isi nama lengkap.');
    validateUsername(username);
    if (state.users.any((u) => u.username == username)) {
      throw const AuthException(
        'Username sudah digunakan. Pilih username lain.',
      );
    }
    validatePin(pin);
    final credential = await ref.read(pinHasherProvider).hash(pin);
    final serial = nextSerial;
    final id = 'staff:$serial';
    final user = UserProfile(
      id: id,
      username: username,
      gender: gender,
      serialNumber: serial,
      name: name.trim(),
      role: role,
      cashierCode: id,
      branch: 'Cabang Utama Pramuka',
      phone: phone.trim(),
      pinActive: true,
      terminalSession: 'Perangkat ini',
    );
    final users = [...state.users, user];
    await _save(users, {..._credentials, id: credential}, lastSerial: serial);
    // Setup ends on the login screen so the owner can verify their credentials.
    state = AuthState(
      users: users,
      currentUser: setup ? null : state.currentUser,
    );
  }

  Future<void> _checkPin(String? id, String pin) async {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      throw const AuthException(
        'Terlalu banyak percobaan. Tunggu 1 menit lalu coba lagi.',
      );
    }
    final credential = _credentials[id];
    final matches =
        credential != null &&
        RegExp(r'^\d{6}$').hasMatch(pin) &&
        await ref.read(pinHasherProvider).verify(pin, credential);
    if (!matches) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
        _failedAttempts = 0;
      }
      await _save(state.users, _credentials);
      throw AuthException(
        _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)
            ? 'Terlalu banyak percobaan. Tunggu 1 menit lalu coba lagi.'
            : 'Username atau PIN salah. Periksa dan coba lagi.',
      );
    }
    _failedAttempts = 0;
    _lockedUntil = null;
    await _save(state.users, _credentials);
  }

  Future<void> login(
    String username,
    String pin, {
    bool keepLoggedIn = false,
  }) => _exclusive(() async {
    if (state.loading || state.storageError != null || state.needsSetup) {
      throw const AuthException('Akun belum siap.');
    }
    final generation = _sessionGeneration;
    username = normalizeUsername(username);
    final matches = state.users.where((u) => u.username == username);
    final user = matches.isEmpty ? null : matches.first;
    await _checkPin(user?.id, pin);
    if (generation != _sessionGeneration) {
      throw const AuthException('Sesi dibatalkan. Silakan masuk kembali.');
    }
    if (user == null) throw const AuthException('Username atau PIN salah.');
    if (!user.isActive) {
      throw const AuthException(
        'Akun dinonaktifkan. Hubungi Admin untuk mengaktifkannya.',
      );
    }
    final now = _now;
    final previous = _session;
    _session = _LoginSession(
      user.id,
      now,
      keepLoggedIn ? null : now.add(const Duration(hours: 8)),
    );
    try {
      await _save(state.users, _credentials);
    } catch (_) {
      _session = previous;
      rethrow;
    }
    ref.invalidate(cartProvider);
    ref.invalidate(mainNavIndexProvider);
    state = AuthState(users: state.users, currentUser: user);
    _scheduleExpiry();
  });

  Future<void> logout() => _exclusive(() async {
    try {
      await _save(state.users, _credentials, clearSession: true);
    } catch (_) {
      throw const AuthException(
        'Belum dapat keluar akun. Coba lagi agar sesi di perangkat ini dihapus.',
      );
    }
    _endSession();
  });

  void _scheduleExpiry() {
    _sessionTimer?.cancel();
    final expiresAt = _session?.expiresAt;
    if (expiresAt != null) {
      _sessionTimer = Timer(expiresAt.difference(_now), checkSession);
    }
  }

  void checkSession() {
    if (_session != null && !_session!.isValidAt(_now)) {
      _endSession(expired: true);
    } else {
      _scheduleExpiry();
    }
  }

  void _endSession({bool expired = false}) {
    _sessionGeneration++;
    _sessionTimer?.cancel();
    _session = null;
    ref.invalidate(cartProvider);
    ref.invalidate(mainNavIndexProvider);
    state = AuthState(
      users: state.users,
      loginNotice: expired
          ? 'Sesi berakhir. Masuk kembali untuk melanjutkan.'
          : null,
    );
  }

  Future<void> changePin(String oldPin, String newPin) => _exclusive(() async {
    final user = requireUser();
    validatePin(newPin);
    await _checkPin(user.id, oldPin);
    final credential = await ref.read(pinHasherProvider).hash(newPin);
    await _save(state.users, {..._credentials, user.id: credential});
  });

  Future<void> updateUser(
    String id,
    UserRole role, {
    String? newPin,
    bool? active,
    String? name,
    String? phone,
    String? username,
    StaffGender? gender,
  }) => _exclusive(() async {
    requireAdmin();
    final target = state.users.firstWhere((u) => u.id == id);
    if (id == state.currentUser!.id &&
        (role != target.role || active == false)) {
      throw const AuthException(
        'Peran dan status akun yang sedang digunakan tidak dapat diubah.',
      );
    }
    if (name != null && name.trim().isEmpty) {
      throw const AuthException('Isi nama lengkap.');
    }
    final normalizedUsername = username == null
        ? null
        : normalizeUsername(username);
    if (normalizedUsername != null) {
      validateUsername(normalizedUsername);
      if (state.users.any(
        (u) => u.id != id && u.username == normalizedUsername,
      )) {
        throw const AuthException(
          'Username sudah digunakan. Pilih username lain.',
        );
      }
    }
    final updated = target.copyWith(
      username: normalizedUsername,
      gender: gender,
      role: role,
      isActive: active,
      name: name?.trim(),
      phone: phone?.trim(),
    );
    final users = state.users.map((u) => u.id == id ? updated : u).toList();
    if (!users.any((u) => u.isAdmin && u.isActive)) {
      throw const AuthException('Minimal satu Admin harus tetap aktif.');
    }
    final credentials = {..._credentials};
    if (newPin != null && newPin.isNotEmpty) {
      validatePin(newPin);
      credentials[id] = await ref.read(pinHasherProvider).hash(newPin);
    }
    await _save(users, credentials);
    state = AuthState(
      users: users,
      currentUser: state.currentUser?.id == id ? updated : state.currentUser,
    );
  });
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
