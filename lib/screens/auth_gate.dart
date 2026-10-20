import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).checkSession();
      ref.read(sessionProvider.notifier).checkDay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.storageError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 16),
                    Text(auth.storageError!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Coba lagi',
                      onPressed: () => ref.read(authProvider.notifier).load(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (auth.currentUser == null) {
      return LoginScreen(
        key: ValueKey(auth.needsSetup),
        setup: auth.needsSetup,
      );
    }
    // Replacing this navigator on sign-out removes checkout and management routes.
    return _AuthenticatedApp(key: ValueKey(auth.currentUser!.id));
  }
}

class _AuthenticatedApp extends StatefulWidget {
  const _AuthenticatedApp({super.key});
  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigator.currentState!.pop(result),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const MainNavigationScreen()),
    ),
  );
}
