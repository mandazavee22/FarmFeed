// FarmFeed Application Constants

class AppConstants {
  AppConstants._();

  // ── Network ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://10.50.1.253:5000/api';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Storage Keys ──────────────────────────────────────────────────────────────
  static const String tokenKey = 'farmfeed_jwt_token';
  static const String userKey = 'farmfeed_user';
  static const String roleKey = 'farmfeed_role';

  // ── User Roles ────────────────────────────────────────────────────────────────
  static const String roleFarmer = 'farmer';
  static const String roleSupplier = 'supplier';

  // ── Zimbabwe Provinces ────────────────────────────────────────────────────────
  static const List<String> zimbabweProvinces = [
    'Harare',
    'Bulawayo',
    'Manicaland',
    'Mashonaland Central',
    'Mashonaland East',
    'Mashonaland West',
    'Masvingo',
    'Matabeleland North',
    'Matabeleland South',
    'Midlands',
  ];

  // ── Livestock Types ───────────────────────────────────────────────────────────
  static const List<String> livestockTypes = [
    'Cattle (Beef)',
    'Cattle (Dairy)',
    'Goats',
    'Poultry (Layers)',
    'Poultry (Broilers)',
    'Pigs',
    'Sheep',
  ];

  // ── Production Goals ──────────────────────────────────────────────────────────
  static const List<String> productionGoals = [
    'Meat',
    'Milk',
    'Eggs',
    'Mixed',
    'Breeding',
  ];

  // ── App Info ──────────────────────────────────────────────────────────────────
  static const String appName = 'FarmFeed';
  static const String appTagline = 'Smart Feed. Better Yields.';
  static const String appVersion = '1.0.0';
}
