class UserModel {
  final String uid;
  final String email;
  final String phone;
  final String role;
  final bool approved;
  final String? firstName;
  final String? lastName;

  UserModel({
    required this.uid,
    required this.email,
    required this.phone,
    required this.role,
    required this.approved,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phone': phone,
      'role': role,
      'approved': approved,
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      phone: map['phone'],
      role: map['role'],
      approved: map['approved'],
      firstName: map['firstName'],
      lastName: map['lastName'],
    );
  }
}