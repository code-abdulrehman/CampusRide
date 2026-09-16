import 'enums.dart';

class CampusUser {
  final String userId;
  String name;
  String email;
  String phone;
  String studentId;
  String department;
  String semester;
  String mainCampus;
  String? profilePictureUrl;
  UserVerificationStatus verificationStatus;
  AccountStatus accountStatus;
  double rating;
  int completedRides;
  int cancelledRides;
  String? emergencyContactName;
  String? emergencyContactPhone;
  DateTime createdAt;

  bool get isStudentVerified => verificationStatus == UserVerificationStatus.studentVerified;
  bool get isDriverVerified =>
      verificationStatus == UserVerificationStatus.driverVerified ||
      verificationStatus == UserVerificationStatus.driverPending;

  double get reliabilityScore {
    final total = completedRides + cancelledRides;
    if (total == 0) return 100.0;
    return ((completedRides / total) * 100).roundToDouble();
  }

  CampusUser({
    required this.userId,
    required this.name,
    required this.email,
    this.phone = '',
    required this.studentId,
    this.department = '',
    this.semester = '',
    this.mainCampus = 'Main Campus',
    this.profilePictureUrl,
    this.verificationStatus = UserVerificationStatus.none,
    this.accountStatus = AccountStatus.active,
    this.rating = 0.0,
    this.completedRides = 0,
    this.cancelledRides = 0,
    this.emergencyContactName,
    this.emergencyContactPhone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'studentId': studentId,
        'department': department,
        'semester': semester,
        'mainCampus': mainCampus,
        'verificationStatus': verificationStatus.index,
        'accountStatus': accountStatus.index,
        'rating': rating,
        'completedRides': completedRides,
        'cancelledRides': cancelledRides,
      };

  factory CampusUser.fromJson(Map<String, dynamic> json) => CampusUser(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        studentId: json['studentId'] as String,
        department: json['department'] as String? ?? '',
        semester: json['semester'] as String? ?? '',
        mainCampus: json['mainCampus'] as String? ?? 'Main Campus',
        verificationStatus: UserVerificationStatus.values[json['verificationStatus'] as int? ?? 0],
        accountStatus: AccountStatus.values[json['accountStatus'] as int? ?? 0],
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        completedRides: json['completedRides'] as int? ?? 0,
        cancelledRides: json['cancelledRides'] as int? ?? 0,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
      );
}
