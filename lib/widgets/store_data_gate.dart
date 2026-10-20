import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'custom_app_bar.dart';
import 'primary_button.dart';

class StoreDataGate extends ConsumerWidget {
  final Widget child;
  const StoreDataGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(sessionProvider);
    if (!store.loading && store.error == null) return child;
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: const CustomAppBar(title: 'Data Toko'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    store.loading
                        ? 'Memuat data toko…'
                        : 'Data toko belum tersedia',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (store.loading)
                    const LinearProgressIndicator()
                  else ...[
                    Text(
                      store.error!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Coba Lagi',
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).load(),
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
