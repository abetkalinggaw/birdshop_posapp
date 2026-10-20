import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

class ChangePinDialog extends ConsumerStatefulWidget {
  const ChangePinDialog({super.key});
  @override
  ConsumerState<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<ChangePinDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).changePin(_old.text, _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool confirmation = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_busy,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label),
    textInputAction: confirmation ? TextInputAction.done : TextInputAction.next,
    validator: (v) => v!.length != 6
        ? 'Masukkan 6 angka.'
        : confirmation && v != _new.text
        ? 'PIN belum cocok.'
        : null,
    onFieldSubmitted: confirmation ? (_) => _save() : null,
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Ubah PIN'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verifikasi PIN saat ini, lalu pilih PIN baru.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _field(_old, 'PIN saat ini'),
              const SizedBox(height: 16),
              _field(_new, 'PIN baru'),
              const SizedBox(height: 16),
              _field(_confirm, 'Ulangi PIN baru', confirmation: true),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.alertCritical),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        PrimaryButton(text: 'Simpan PIN', isLoading: _busy, onPressed: _save),
      ],
    ),
  );
}
