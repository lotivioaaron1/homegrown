class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'athlete', 'coach', 'organizer'
  final String? barangay;
  final String? sport;
  final String? organization;
  final String? contactInfo;
  final int? pointingScore;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.barangay,
    this.sport,
    this.organization,
    this.contactInfo,
    this.pointingScore = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'barangay': barangay,
      'sport': sport,
      'organization': organization,
      'contactInfo': contactInfo,
      'pointingScore': pointingScore ?? 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'athlete',
      barangay: map['barangay'],
      sport: map['sport'],
      organization: map['organization'],
      contactInfo: map['contactInfo'],
      pointingScore: map['pointingScore'] ?? 0,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}