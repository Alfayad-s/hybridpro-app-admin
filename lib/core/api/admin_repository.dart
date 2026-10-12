import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'engagement_models.dart';
import 'chat_models.dart';
import 'gym_models.dart';
import 'models.dart';
import '../../features/sessions/session_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<({String token, String email})> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = res.data ?? {};
      final token = data['token'] as String?;
      final loggedEmail = data['email'] as String? ?? email;
      if (token == null || token.isEmpty) {
        throw ApiException('Login failed: no token returned');
      }
      return (token: token, email: loggedEmail);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AdminStats> stats() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/stats');
      return AdminStats.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<AdminClient>> clients({
    String? q,
    String? status,
    String? planId,
    bool? expiringSoon,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/clients',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (status != null && status.isNotEmpty) 'status': status,
          if (planId != null && planId.isNotEmpty) 'planId': planId,
          if (expiringSoon == true) 'expiringSoon': '1',
        },
      );
      final list = res.data?['clients'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => AdminClient.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> grantClient({
    required String email,
    String? mobile,
    required String planId,
  }) async {
    try {
      await _dio.post(
        '/admin/clients',
        data: {
          'email': email.trim(),
          if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
          'planId': planId,
        },
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ClientDetail> clientDetail(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/clients/$id');
      return ClientDetail.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> patchClient(
    String id, {
    required String action,
    int? days,
    String? planId,
    String? notes,
  }) async {
    try {
      await _dio.patch(
        '/admin/clients/$id',
        data: {
          'action': action,
          if (days != null) 'days': days,
          if (planId != null) 'planId': planId,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Checkin> addCheckin(
    String clientId, {
    String? checkinDate,
    String? weight,
    String? adherence,
    String? clientUpdate,
    String? coachReply,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/checkins',
        data: {
          if (checkinDate != null) 'checkinDate': checkinDate,
          if (weight != null) 'weight': weight,
          if (adherence != null) 'adherence': adherence,
          if (clientUpdate != null) 'clientUpdate': clientUpdate,
          if (coachReply != null) 'coachReply': coachReply,
        },
      );
      return Checkin.fromJson(
        Map<String, dynamic>.from(res.data?['checkin'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Checkin> replyCheckin(
    String clientId,
    String checkinId, {
    required String coachReply,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/clients/$clientId/checkins/$checkinId',
        data: {'coachReply': coachReply},
      );
      return Checkin.fromJson(
        Map<String, dynamic>.from(res.data?['checkin'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedPlan> assignWorkout(
    String clientId, {
    String? name,
    String? description,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/workout-plans',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          'days': days,
        },
      );
      return AssignedPlan.fromJson(
        Map<String, dynamic>.from(res.data?['plan'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedPlan> updateWorkout(
    String clientId,
    String planId, {
    String? name,
    String? description,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/clients/$clientId/workout-plans/$planId',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          'days': days,
        },
      );
      return AssignedPlan.fromJson(
        Map<String, dynamic>.from(res.data?['plan'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> unassignWorkout(String clientId, String planId) async {
    try {
      await _dio.delete('/admin/clients/$clientId/workout-plans/$planId');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedMealPlan> assignMealPlan(
    String clientId, {
    String? name,
    String? description,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/meal-plans',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          'days': days,
        },
      );
      return AssignedMealPlan.fromJson(
        Map<String, dynamic>.from(res.data?['mealPlan'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedMealPlan> updateMealPlan(
    String clientId,
    String planId, {
    String? name,
    String? description,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/clients/$clientId/meal-plans/$planId',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          'days': days,
        },
      );
      return AssignedMealPlan.fromJson(
        Map<String, dynamic>.from(res.data?['mealPlan'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> unassignMealPlan(String clientId, String planId) async {
    try {
      await _dio.delete('/admin/clients/$clientId/meal-plans/$planId');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedWaterChallenge> assignWaterChallenge(
    String clientId, {
    String? title,
    String? description,
    required int targetMlPerDay,
    required int durationDays,
    String? startDate,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/water-challenges',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          'targetMlPerDay': targetMlPerDay,
          'durationDays': durationDays,
          if (startDate != null) 'startDate': startDate,
        },
      );
      return AssignedWaterChallenge.fromJson(
        Map<String, dynamic>.from(res.data?['waterChallenge'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AssignedWaterChallenge> updateWaterChallenge(
    String clientId,
    String challengeId, {
    String? title,
    String? description,
    required int targetMlPerDay,
    required int durationDays,
    String? startDate,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/clients/$clientId/water-challenges/$challengeId',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          'targetMlPerDay': targetMlPerDay,
          'durationDays': durationDays,
          if (startDate != null) 'startDate': startDate,
        },
      );
      return AssignedWaterChallenge.fromJson(
        Map<String, dynamic>.from(res.data?['waterChallenge'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> unassignWaterChallenge(
    String clientId,
    String challengeId,
  ) async {
    try {
      await _dio.delete(
        '/admin/clients/$clientId/water-challenges/$challengeId',
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<StoreTaxonomyAdmin>> productCategories() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/products/categories',
      );
      final list = res.data?['categories'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => StoreTaxonomyAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreTaxonomyAdmin> createProductCategory(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/products/categories',
        data: body,
      );
      return StoreTaxonomyAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['category'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreTaxonomyAdmin> updateProductCategory(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/products/categories/$id',
        data: body,
      );
      return StoreTaxonomyAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['category'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteProductCategory(String id) async {
    try {
      await _dio.delete('/admin/products/categories/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<StoreTaxonomyAdmin>> productKinds() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/products/kinds');
      final list = res.data?['kinds'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => StoreTaxonomyAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreTaxonomyAdmin> createProductKind(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/products/kinds',
        data: body,
      );
      return StoreTaxonomyAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['kind'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreTaxonomyAdmin> updateProductKind(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/products/kinds/$id',
        data: body,
      );
      return StoreTaxonomyAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['kind'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteProductKind(String id) async {
    try {
      await _dio.delete('/admin/products/kinds/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<StoreProductAdmin>> products({String? q, String? category}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/products',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (category != null && category.isNotEmpty) 'category': category,
        },
      );
      final list = res.data?['products'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => StoreProductAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreProductAdmin> createProduct(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/products',
        data: body,
      );
      return StoreProductAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['product'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StoreProductAdmin> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/products/$id',
        data: body,
      );
      return StoreProductAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['product'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/admin/products/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<String> uploadProductMedia({
    required String filePath,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/products/media',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final url = res.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ApiException('Upload failed: no URL returned');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ShopOrderAdmin> updateShopOrder(
    String id,
    List<ShopOrderItemAdmin> items,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/shop-orders/$id',
        data: {'items': items.map((item) => item.toJson()).toList()},
      );
      return ShopOrderAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['order'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ShopOrderAdmin> acceptShopOrder(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/shop-orders/$id/accept',
      );
      return ShopOrderAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['order'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ShopOrderAdmin> rejectShopOrder(String id, String reason) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/shop-orders/$id/reject',
        data: {'reason': reason},
      );
      return ShopOrderAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['order'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<ShopOrderAdmin>> shopOrders({String? q}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/shop-orders',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );
      final list = res.data?['orders'] as List? ?? [];
      return list
          .map((e) => ShopOrderAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<ShopPromoAdmin>> shopPromos({String? placement}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/shop-promos',
        queryParameters: {
          if (placement != null && placement.isNotEmpty) 'placement': placement,
        },
      );
      final list = res.data?['promos'] as List? ?? [];
      return list
          .map((e) => ShopPromoAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ShopPromoAdmin> createShopPromo(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/shop-promos',
        data: body,
      );
      return ShopPromoAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['promo'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ShopPromoAdmin> updateShopPromo(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/shop-promos/$id',
        data: body,
      );
      return ShopPromoAdmin.fromJson(
        Map<String, dynamic>.from(res.data?['promo'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteShopPromo(String id) async {
    try {
      await _dio.delete('/admin/shop-promos/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<Exercise>> exercises({String? q, String library = 'workout'}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/exercises',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          'library': library,
        },
      );
      final list = res.data?['exercises'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> createExercise(Map<String, dynamic> body) async {
    try {
      await _dio.post('/admin/exercises', data: body);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> updateExercise(String id, Map<String, dynamic> body) async {
    try {
      await _dio.patch('/admin/exercises/$id', data: body);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteExercise(String id) async {
    try {
      await _dio.delete('/admin/exercises/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<LibraryMeal>> libraryMeals({String? q, String? type}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/meals',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final list = res.data?['meals'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => LibraryMeal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> createLibraryMeal(Map<String, dynamic> body) async {
    try {
      await _dio.post('/admin/meals', data: body);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> updateLibraryMeal(String id, Map<String, dynamic> body) async {
    try {
      await _dio.patch('/admin/meals/$id', data: body);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> deleteLibraryMeal(String id) async {
    try {
      await _dio.delete('/admin/meals/$id');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<String> uploadExerciseMedia({
    required String filePath,
    required String filename,
    required String kind,
    String? exerciseKey,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
        'kind': kind,
        if (exerciseKey != null && exerciseKey.isNotEmpty) 'exerciseKey': exerciseKey,
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/exercises/media',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final url = res.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ApiException('Upload failed: no URL returned');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<({List<AdminPayment> payments, PaymentTotals totals})> payments({
    String? q,
    String? planId,
    String? status,
    String? from,
    String? to,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/payments',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (planId != null && planId.isNotEmpty) 'planId': planId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        },
      );
      final list = res.data?['payments'] as List? ?? [];
      final payments = list
          .whereType<Map>()
          .map((e) => AdminPayment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final totals = PaymentTotals.fromJson(
        Map<String, dynamic>.from(res.data?['totals'] as Map? ?? {}),
      );
      return (payments: payments, totals: totals);
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<ContactSubmission>> contacts({String? q, String? status}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/contacts',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final list = res.data?['submissions'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => ContactSubmission.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ContactDetail> contactDetail(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/contacts/$id');
      return ContactDetail.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<({ContactSubmission submission, AdminClient? subscription})> grantContact(
    String id, {
    String planId = 'performance',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/contacts/$id/grant',
        data: {'planId': planId},
      );
      final sub = res.data?['subscription'];
      return (
        submission: ContactSubmission.fromJson(
          Map<String, dynamic>.from(res.data?['submission'] as Map? ?? {}),
        ),
        subscription: sub is Map
            ? AdminClient.fromJson(Map<String, dynamic>.from(sub))
            : null,
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    try {
      await _dio.post(
        '/admin/devices',
        data: {'token': token, 'platform': platform},
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> unregisterDevice({String? token}) async {
    try {
      await _dio.delete(
        '/admin/devices',
        data: {if (token != null && token.isNotEmpty) 'token': token},
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<GymSession>> activeGymSessions() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/gym/active');
      final list = res.data?['sessions'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => GymSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<GymSession>> clientGymHistory(String clientId) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/admin/clients/$clientId/gym');
      final list = res.data?['sessions'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => GymSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<ChatInboxItem>> chatInbox() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/chat/inbox');
      final list = res.data?['conversations'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => ChatInboxItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ChatThread> hyroxChat({int? limit}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/hyrox/chat',
        queryParameters: {if (limit != null) 'limit': limit},
      );
      return ChatThread.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ChatMessage> sendHyroxChat({required String body, String? imageUrl}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/hyrox/chat/messages',
        data: {
          'body': body,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        },
      );
      return ChatMessage.fromJson(
        Map<String, dynamic>.from(res.data?['message'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markHyroxRead() async {
    try {
      await _dio.post('/admin/hyrox/chat/read');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ChatThread> clientChat(String clientId, {int? limit}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/clients/$clientId/chat',
        queryParameters: {if (limit != null) 'limit': limit},
      );
      return ChatThread.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<ChatMessage> sendClientChat(
    String clientId, {
    required String body,
    String? imageUrl,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/chat/messages',
        data: {
          'body': body,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        },
      );
      return ChatMessage.fromJson(
        Map<String, dynamic>.from(res.data?['message'] as Map? ?? {}),
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<EngagementAdminConfig> engagementConfig() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/engagement');
      return EngagementAdminConfig.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<EngagementAdminConfig> updateEngagementSettings({
    required int dailyLimit,
    required int quietStartMinutes,
    required int quietEndMinutes,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/admin/engagement',
        data: {
          'dailyLimit': dailyLimit,
          'quietStartMinutes': quietStartMinutes,
          'quietEndMinutes': quietEndMinutes,
        },
      );
      return EngagementAdminConfig.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<EngagementAdminConfig> updateEngagementTemplate({
    required String type,
    required String title,
    required String body,
    required bool enabled,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/admin/engagement/templates/$type',
        data: {'title': title, 'body': body, 'enabled': enabled},
      );
      return EngagementAdminConfig.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> markClientChatRead(String clientId) async {
    try {
      await _dio.post('/admin/clients/$clientId/chat/read');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<CoachAvailability> availability() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/availability');
      return CoachAvailability.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<CoachAvailability> saveAvailability({
    required List<CoachWindow> windows,
    required List<CoachTimeOff> timeOff,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/admin/availability',
        data: {
          'windows': [for (final window in windows) window.toJson()],
          'timeOff': [for (final block in timeOff) block.toJson()],
        },
      );
      return CoachAvailability.fromJson(res.data ?? {});
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<SessionSlot>> sessionSlots() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/sessions/slots');
      final raw = res.data?['slots'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) SessionSlot.fromJson(item),
      ];
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<List<CoachSession>> sessions({String? clientId, bool upcoming = false}) async {
    try {
      final res = clientId == null
          ? await _dio.get<Map<String, dynamic>>(
              '/admin/sessions',
              queryParameters: {if (upcoming) 'upcoming': '1'},
            )
          : await _dio.get<Map<String, dynamic>>('/admin/clients/$clientId/sessions');
      final raw = res.data?['sessions'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) CoachSession.fromJson(item),
      ];
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<CoachSession> bookClientSession({
    required String clientId,
    required DateTime startsAt,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/clients/$clientId/sessions',
        data: {'startsAt': startsAt.toUtc().toIso8601String()},
      );
      return CoachSession.fromJson(
        (res.data?['session'] as Map<String, dynamic>?) ?? {},
      );
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> cancelSession(String id) async {
    try {
      await _dio.post('/admin/sessions/$id/cancel');
    } on DioException catch (e) {
      throw ApiException(messageFromDio(e), statusCode: e.response?.statusCode);
    }
  }
}
