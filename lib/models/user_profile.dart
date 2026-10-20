enum UserRole {
  admin('Admin (Owner)', 'ADM'),
  cashier('Cashier (Employee)', 'CSH');

  final String label;
  final String code;
  const UserRole(this.label, this.code);
}

enum StaffGender {
  unspecified('Belum diisi', '0'),
  male('Laki-laki', '1'),
  female('Perempuan', '2'),
  other('Lainnya', '3');

  final String label;
  final String code;
  const StaffGender(this.label, this.code);
}

class UserProfile {
  // Immutable account identity used by credentials, shifts and transactions.
  // The formatted Staff ID is derived separately so profile edits keep history.
  final String id;
  final String username;
  final int serialNumber;
  final StaffGender gender;
  final String name;
  final UserRole role;
  final String cashierCode;
  final String branch;
  final String phone;
  final bool pinActive;
  final String terminalSession;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.username,
    required this.serialNumber,
    required this.gender,
    required this.name,
    required this.role,
    required this.cashierCode,
    required this.branch,
    required this.phone,
    required this.pinActive,
    required this.terminalSession,
    this.isActive = true,
  });

  bool get isAdmin => role == UserRole.admin;
  String get staffId => formatStaffId(role, gender, serialNumber);
  static String formatStaffId(UserRole role, StaffGender gender, int serial) =>
      '${role.code}-${gender.code}${serial.toString().padLeft(4, '0')}';

  UserProfile copyWith({
    String? username,
    StaffGender? gender,
    String? name,
    UserRole? role,
    String? branch,
    String? phone,
    bool? pinActive,
    String? terminalSession,
    bool? isActive,
  }) => UserProfile(
    id: id,
    username: username ?? this.username,
    serialNumber: serialNumber,
    gender: gender ?? this.gender,
    name: name ?? this.name,
    role: role ?? this.role,
    cashierCode: cashierCode,
    branch: branch ?? this.branch,
    phone: phone ?? this.phone,
    pinActive: pinActive ?? this.pinActive,
    terminalSession: terminalSession ?? this.terminalSession,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'serialNumber': serialNumber,
    'gender': gender.name,
    'name': name,
    'role': role.name,
    'cashierCode': cashierCode,
    'branch': branch,
    'phone': phone,
    'isActive': isActive,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    serialNumber: json['serialNumber'] as int,
    gender: StaffGender.values.byName(json['gender'] as String),
    name: json['name'] as String,
    role: UserRole.values.byName(json['role'] as String),
    cashierCode: json['cashierCode'] as String,
    branch: json['branch'] as String,
    phone: json['phone'] as String,
    pinActive: true,
    terminalSession: 'Perangkat ini',
    isActive: json['isActive'] as bool,
  );
}
