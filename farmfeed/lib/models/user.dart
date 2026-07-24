// FarmFeed Data Models

class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String province;
  final String city;
  final String streetAddress;
  final String? locationDescription;
  final String? profilePhotoUrl;
  final Map<String, dynamic>? profile;
  final String? createdAt;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.province,
    required this.city,
    required this.streetAddress,
    this.locationDescription,
    this.profilePhotoUrl,
    this.profile,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      streetAddress: json['street_address'] ?? '',
      locationDescription: json['location_description'],
      profilePhotoUrl: json['profile_photo_url'],
      profile: json['profile'] as Map<String, dynamic>?,
      createdAt: json['created_at'],
    );
  }

  bool get isFarmer => role == 'farmer';
  bool get isSupplier => role == 'supplier';

  String get farmName => profile?['farm_name'] ?? '';
  String get companyName => profile?['company_name'] ?? '';
  List<String> get livestockTypes {
    final types = profile?['livestock_types'];
    if (types is List) return types.map((e) => e.toString()).toList();
    return [];
  }

  String get displayName => isFarmer ? farmName : companyName;
  String get fullAddress => '$streetAddress, $city, $province';
}
