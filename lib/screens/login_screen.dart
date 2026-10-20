import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../models/user_profile.dart';
import '../widgets/staff_identity_fields.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool setup;
  const LoginScreen({super.key, this.setup = false});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  StaffGender? _gender;
  bool _obscure = true;
  bool _busy = false;
  bool _keepLoggedIn = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (widget.setup) {
        await auth.setupOwner(
          _name.text,
          _username.text,
          _pin.text,
          gender: _gender!,
        );
      } else {
        await auth.login(
          _username.text,
          _pin.text,
          keepLoggedIn: _keepLoggedIn,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Tidak dapat masuk. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(authProvider).loginNotice;
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: AppColors.primaryGreen,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'EX-SHA',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            widget.setup
                                ? 'Siapkan akun Owner'
                                : 'Masuk ke toko',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.setup
                                ? 'Buat akun Admin pertama untuk mengelola toko dan akses karyawan.'
                                : 'Gunakan username dan PIN Anda untuk mulai bekerja.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (widget.setup) ...[
                            TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nama lengkap',
                              ),
                              validator: (value) => value!.trim().isEmpty
                                  ? 'Isi nama lengkap.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _username,
                            enabled: !_busy,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              helperText: widget.setup
                                  ? '3–24 karakter. Contoh: abet.owner'
                                  : null,
                            ),
                            validator: (value) =>
                                value!.trim().isEmpty ? 'Isi username.' : null,
                          ),
                          if (widget.setup) ...[
                            const SizedBox(height: 16),
                            StaffGenderField(
                              value: _gender,
                              enabled: !_busy,
                              onChanged: (gender) =>
                                  setState(() => _gender = gender),
                            ),
                            const SizedBox(height: 16),
                            StaffIdPreview(
                              role: UserRole.admin,
                              gender: _gender,
                              serial: ref
                                  .read(authProvider.notifier)
                                  .nextSerial,
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pin,
                            enabled: !_busy,
                            obscureText: _obscure,
                            enableSuggestions: false,
                            autocorrect: false,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            textInputAction: widget.setup
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!widget.setup) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: 'PIN 6 angka',
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Tampilkan PIN'
                                    : 'Sembunyikan PIN',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value!.length == 6 ? null : 'Masukkan 6 angka.',
                          ),
                          if (widget.setup) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: _obscure,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Ulangi PIN',
                              ),
                              validator: (value) => value == _pin.text
                                  ? null
                                  : 'PIN belum cocok.',
                            ),
                          ],
                          if (!widget.setup) ...[
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: _keepLoggedIn,
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _keepLoggedIn = value ?? false,
                                    ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Tetap masuk di perangkat ini',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                _keepLoggedIn
                                    ? 'Tetap masuk hingga Anda keluar akun.'
                                    : 'Keluar otomatis 8 jam setelah masuk.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (_error != null || notice != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error ?? notice!,
                                style: TextStyle(
                                  color: _error != null
                                      ? AppColors.alertCritical
                                      : AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: widget.setup ? 'Buat akun Owner' : 'Masuk',
                            isLoading: _busy,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.setup
                                ? 'Simpan username dan PIN Anda. Owner dapat membuat akun Cashier setelah masuk.'
                                : 'Lupa PIN atau belum punya akun? Hubungi Admin toko.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Row(
                            children: [
                              Icon(
                                Icons.phonelink_lock_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Akun tersimpan di perangkat ini • Bisa masuk tanpa internet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
