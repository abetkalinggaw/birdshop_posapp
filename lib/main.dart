import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: ExShaBirdShopApp()));
}

class ExShaBirdShopApp extends StatelessWidget {
  const ExShaBirdShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EX-SHA Bird Shop POS & Inventory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
