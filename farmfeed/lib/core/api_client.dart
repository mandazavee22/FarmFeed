import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  late final Dio _dio;

  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) {
          handler.next(e);
        },
      ),
    );
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final resp = await _dio.post('/auth/register', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio
        .post('/auth/login', data: {'email': email, 'password': password});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get('/auth/me');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) async {
    final resp = await _dio.put('/auth/me', data: body);
    return resp.data as Map<String, dynamic>;
  }

  // ── Farmer ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFarmerDashboard() async {
    final resp = await _dio.get('/farmer/dashboard');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLivestock() async {
    final resp = await _dio.get('/farmer/livestock');
    return resp.data as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> deleteLivestockRecord(int recordId) async {
    final resp = await _dio.delete('/farmer/livestock/$recordId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLivestockRecord(Map<String, dynamic> body) async {
    final resp = await _dio.post('/farmer/livestock', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLivestockRecord(int id, Map<String, dynamic> data) async {
    final resp = await _dio.put('/farmer/livestock/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Notifications ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications() async {
    final resp = await _dio.get('/auth/notifications');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final resp = await _dio.post('/auth/notifications/read-all');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markNotificationRead(int id) async {
    final resp = await _dio.post('/auth/notifications/$id/read');
    return resp.data as Map<String, dynamic>;
  }

  // ── Supplier Management ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSupplierOrders() async {
    final resp = await _dio.get('/supplier/orders');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrderStatus(int id, String status, {String? notes}) async {
    final resp = await _dio.post('/supplier/orders/$id/status', data: {
      'status': status,
      'notes': notes,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> optimizeFeed(int livestockId, List<String> ingredientIds) async {
    final resp = await _dio.post('/farmer/optimize', data: {
      'livestock_record_id': livestockId,
      'ingredient_ids': ingredientIds,
    });
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> predictPerformance(int formulationId) async {
    final resp = await _dio.post('/farmer/predict', data: {'formulation_id': formulationId});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> simulateScenarios(int formulationId) async {
    final resp = await _dio.post('/farmer/simulate', data: {'formulation_id': formulationId});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> initiateProcurement(int formulationId) async {
    final resp = await _dio.post('/farmer/procure', data: {'formulation_id': formulationId});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFarmerInventory() async {
    final resp = await _dio.get('/farmer/inventory');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addFarmerInventory(Map<String, dynamic> body) async {
    final resp = await _dio.post('/farmer/inventory', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateFarmerInventory(int itemId, Map<String, dynamic> body) async {
    final resp = await _dio.put('/farmer/inventory/$itemId', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFarmerHistory() async {
    final resp = await _dio.get('/farmer/history');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteFarmerInventory(int itemId) async {
    final resp = await _dio.delete('/farmer/inventory/$itemId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBids() async {
    final resp = await _dio.get('/farmer/bids');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptBid(int bidId) async {
    final resp = await _dio.post('/farmer/bids/$bidId/accept');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectBid(int bidId) async {
    final resp = await _dio.post('/farmer/bids/$bidId/reject');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeRequest(int reqId) async {
    final resp = await _dio.post('/farmer/procurement/$reqId/close');
    return resp.data as Map<String, dynamic>;
  }

  // ── Supplier ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSupplierDashboard() async {
    final resp = await _dio.get('/supplier/dashboard');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAllSuppliers() async {
    final resp = await _dio.get('/supplier/all');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSupplierIngredients() async {
    final resp = await _dio.get('/supplier/ingredients');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addSupplierIngredient(Map<String, dynamic> data) async {
    final resp = await _dio.post('/supplier/ingredients', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSupplierIngredient(int id, Map<String, dynamic> data) async {
    final resp = await _dio.put('/supplier/ingredients/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteSupplierIngredient(int id) async {
    final resp = await _dio.delete('/supplier/ingredients/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitBid(int reqId, Map<String, dynamic> data) async {
    final resp = await _dio.post('/supplier/procurement/$reqId/bid', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOpenMarket() async {
    final resp = await _dio.get('/supplier/open_market');
    return resp.data as Map<String, dynamic>;
  }

  // ── Farmer Analytics ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMarketIngredients() async {
    final resp = await _dio.get('/farmer/marketplace');
    return resp.data as Map<String, dynamic>;
  }

  // ── Community ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getForumTopics() async {
    final resp = await _dio.get('/community/forum');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createForumTopic(Map<String, dynamic> body) async {
    final resp = await _dio.post('/community/forum', data: body);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getForumTopic(int topicId) async {
    final resp = await _dio.get('/community/forum/$topicId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replyToTopic(int topicId, String content) async {
    final resp = await _dio.post('/community/forum/$topicId/reply', data: {'content': content});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInbox() async {
    final resp = await _dio.get('/community/inbox');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversation(int partnerId) async {
    final resp = await _dio.get('/community/inbox/$partnerId');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(int receiverId, String content) async {
    final resp = await _dio.post('/community/message', data: {'receiver_id': receiverId, 'content': content});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCommunityUsers() async {
    final resp = await _dio.get('/community/users');
    return resp.data as Map<String, dynamic>;
  }

  // ── Health ────────────────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final resp = await _dio.get('/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
