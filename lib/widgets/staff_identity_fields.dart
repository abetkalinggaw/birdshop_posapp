import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class StaffGenderField extends StatelessWidget {
  final StaffGender? value;
  final bool enabled;
  final ValueChanged<StaffGender?> onChanged;
  const StaffGenderField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<StaffGender>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Gender'),
    items: StaffGender.values
        .map(
          (gender) =>
              DropdownMenuItem(value: gender, child: Text(gender.label)),
        )
        .toList(),
    onChanged: enabled ? onChanged : null,
    validator: (gender) => gender == null ? 'Pilih gender.' : null,
  );
}

class StaffIdPreview extends StatelessWidget {
  final UserRole role;
  final StaffGender? gender;
  final int serial;
  const StaffIdPreview({
    super.key,
    required this.role,
    required this.gender,
    required this.serial,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(
      labelText: 'ID Staff (otomatis)',
      helperText: 'Identitas staff. Login menggunakan username.',
    ),
    child: Text(
      gender == null
          ? 'Pilih gender untuk melihat ID'
          : UserProfile.formatStaffId(role, gender!, serial),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
