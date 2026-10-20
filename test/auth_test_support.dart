import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/services/auth_store.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';

const testOwner = UserProfile(
  id: 'staff:1',
  username: 'owner-01',
  serialNumber: 1,
  gender: StaffGender.male,
  name: 'Owner Test',
  role: UserRole.admin,
  cashierCode: 'staff:1',
  branch: 'Cabang Utama Pramuka',
  phone: '',
  pinActive: true,
  terminalSession: 'Perangkat ini',
);

class SignedInOwner extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(users: [testOwner], currentUser: testOwner);
}

class MemoryAuthStore implements AuthStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('storage unavailable');
    this.value = value;
  }
}

ProviderContainer authContainer(
  MemoryAuthStore store, {
  DateTime Function()? now,
  AuthStore? shifts,
}) => ProviderContainer(
  overrides: [
    authStoreProvider.overrideWithValue(store),
    shiftStoreProvider.overrideWithValue(shifts ?? MemoryAuthStore()),
    pinHasherProvider.overrideWithValue(const PinHasher(iterations: 1000)),
    if (now != null) authClockProvider.overrideWithValue(now),
  ],
);

Future<void> awaitAuthLoaded(ProviderContainer container) async {
  container.read(authProvider);
  while (container.read(authProvider).loading) {
    await Future<void>.delayed(Duration.zero);
  }
  container.read(sessionProvider);
  while (container.read(sessionProvider).loading) {
    await Future<void>.delayed(Duration.zero);
  }
}

String accountId(ProviderContainer container, String username) => container
    .read(authProvider)
    .users
    .firstWhere((u) => u.username == AuthNotifier.normalizeUsername(username))
    .id;
