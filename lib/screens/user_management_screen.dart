import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_controls.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/staff_identity_fields.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});
  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _filter = 'Semua';

  Future<void> _setActive(UserProfile user) async {
    try {
      await ref
          .read(authProvider.notifier)
          .updateUser(user.id, user.role, active: !user.isActive);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _edit([UserProfile? user]) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => StaffAccountScreen(user: user)),
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.currentUser?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Akses hanya untuk Admin.')),
      );
    }
    final users = auth.users
        .where(
          (u) =>
              _filter == 'Semua' ||
              (_filter == 'Aktif' ? u.isActive : !u.isActive),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        slivers: [
          SliverCustomAppBar(
            title: 'Akun staff',
            subtitle: '${auth.users.length} akun di perangkat ini',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: ['Semua', 'Aktif', 'Nonaktif']
                    .map(
                      (label) => AppFilterChip(
                        label: label,
                        selected: _filter == label,
                        onTap: () => setState(() => _filter = label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (users.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Tidak ada akun dalam filter ini.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final user = users[index];
                  final isSelf = user.id == auth.currentUser!.id;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: user.isActive,
                                activeTrackColor: AppColors.primaryGreen,
                                onChanged: isSelf
                                    ? null
                                    : (_) => _setActive(user),
                              ),
                            ],
                          ),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.staffId} · ${user.gender.label}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AppBadge(
                                label: user.role.label,
                                tone: AppBadgeTone.neutral,
                              ),
                              if (isSelf)
                                const AppBadge(
                                  label: 'Akun Anda',
                                  tone: AppBadgeTone.positive,
                                ),
                              if (!user.isActive)
                                const AppBadge(
                                  label: 'Nonaktif',
                                  tone: AppBadgeTone.warning,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.phone.isEmpty
                                      ? 'PIN siap digunakan'
                                      : user.phone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _edit(user),
                                child: const Text('Edit akun'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            text: 'Tambah staff',
            icon: Icons.person_add_outlined,
            onPressed: () => _edit(),
          ),
        ),
      ),
    );
  }
}

class StaffAccountScreen extends ConsumerStatefulWidget {
  final UserProfile? user;
  const StaffAccountScreen({super.key, this.user});
  @override
  ConsumerState<StaffAccountScreen> createState() => _StaffAccountScreenState();
}

class _StaffAccountScreenState extends ConsumerState<StaffAccountScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user?.name,
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.user?.username,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.user?.phone,
  );
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  late StaffGender? _gender = widget.user?.gender;
  late UserRole _role = widget.user?.role ?? UserRole.cashier;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (widget.user == null) {
        await auth.addUser(
          _name.text,
          _username.text,
          _pin.text,
          _role,
          _phone.text,
          gender: _gender!,
        );
      } else {
        await auth.updateUser(
          widget.user!.id,
          _role,
          newPin: _pin.text,
          name: _name.text,
          phone: _phone.text,
          username: _username.text,
          gender: _gender,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.user == null
                  ? 'Akun dibuat. Staff dapat masuk dengan username dan PIN yang ditetapkan.'
                  : 'Akses akun diperbarui.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(authProvider).currentUser;
    if (current?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Akses hanya untuk Admin.')),
      );
    }
    final editing = widget.user != null;
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(title: Text(editing ? 'Edit akun staff' : 'Tambah staff')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing
                        ? 'Perbarui profil, akses, atau PIN untuk ${widget.user!.name}.'
                        : 'Buat akses kerja dengan username yang unik dan PIN 6 angka.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Isi nama lengkap.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _username,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: 'Digunakan untuk masuk pada perangkat ini.',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Isi username.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Peran'),
                    items: UserRole.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: _busy || widget.user?.id == current!.id
                        ? null
                        : (role) => setState(() => _role = role!),
                  ),
                  const SizedBox(height: 16),
                  StaffGenderField(
                    value: _gender,
                    enabled: !_busy,
                    onChanged: (gender) => setState(() => _gender = gender),
                  ),
                  const SizedBox(height: 16),
                  StaffIdPreview(
                    role: _role,
                    gender: _gender,
                    serial:
                        widget.user?.serialNumber ??
                        ref.read(authProvider.notifier).nextSerial,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _role == UserRole.admin
                        ? 'Kelola produk, semua transaksi, laporan, dan akun staff.'
                        : 'Lakukan penjualan, lihat transaksi sendiri, dan kelola sesi kasir.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      enabled: !_busy,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP (opsional)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _pin,
                    enabled: !_busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: editing
                          ? 'PIN baru (opsional)'
                          : 'PIN 6 angka',
                      helperText: editing
                          ? 'Kosongkan untuk mempertahankan PIN saat ini.'
                          : null,
                    ),
                    validator: (v) => editing && v!.isEmpty || v!.length == 6
                        ? null
                        : 'Masukkan 6 angka.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi PIN baru',
                    ),
                    validator: (v) =>
                        v == _pin.text ? null : 'PIN belum cocok.',
                    onFieldSubmitted: (_) => _save(),
                  ),
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
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: editing ? 'Simpan perubahan' : 'Buat akun staff',
                    isLoading: _busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
