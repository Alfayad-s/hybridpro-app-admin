import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_repository.dart';
import 'models.dart';

class ClientsQuery {
  const ClientsQuery({
    this.q = '',
    this.status,
    this.planId,
    this.expiringSoon = false,
  });

  final String q;
  final String? status;
  final String? planId;
  final bool expiringSoon;

  @override
  bool operator ==(Object other) =>
      other is ClientsQuery &&
      other.q == q &&
      other.status == status &&
      other.planId == planId &&
      other.expiringSoon == expiringSoon;

  @override
  int get hashCode => Object.hash(q, status, planId, expiringSoon);
}

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).stats();
});

final clientsListProvider =
    FutureProvider.family<List<AdminClient>, ClientsQuery>((ref, query) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).clients(
        q: query.q,
        status: query.status,
        planId: query.planId,
        expiringSoon: query.expiringSoon,
      );
});

class ExerciseLibraryQuery {
  const ExerciseLibraryQuery({this.q = '', this.library = 'workout'});

  final String q;
  final String library;

  @override
  bool operator ==(Object other) =>
      other is ExerciseLibraryQuery && other.q == q && other.library == library;

  @override
  int get hashCode => Object.hash(q, library);
}

final exercisesProvider =
    FutureProvider.family<List<Exercise>, ExerciseLibraryQuery>((ref, query) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).exercises(
        q: query.q.isEmpty ? null : query.q,
        library: query.library,
      );
});

/// The whole meal library; search and type filters are applied client-side.
final libraryMealsProvider = FutureProvider<List<LibraryMeal>>((ref) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).libraryMeals();
});

final storeProductsProvider =
    FutureProvider.family<List<StoreProductAdmin>, String>((ref, q) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).products(q: q.isEmpty ? null : q);
});

final storeCategoriesProvider =
    FutureProvider<List<StoreTaxonomyAdmin>>((ref) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).productCategories();
});

final storeKindsProvider = FutureProvider<List<StoreTaxonomyAdmin>>((ref) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).productKinds();
});

final shopOrdersProvider =
    FutureProvider.family<List<ShopOrderAdmin>, String>((ref, q) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).shopOrders(q: q.isEmpty ? null : q);
});

final shopPromosProvider =
    FutureProvider.family<List<ShopPromoAdmin>, String>((ref, placement) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).shopPromos(placement: placement);
});

class PaymentsQuery {
  const PaymentsQuery({this.q = '', this.planId, this.status});

  final String q;
  final String? planId;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is PaymentsQuery &&
      other.q == q &&
      other.planId == planId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(q, planId, status);
}

class PaymentsDashboard {
  const PaymentsDashboard({required this.payments, required this.totals});

  final List<AdminPayment> payments;
  final PaymentTotals totals;
}

final paymentsDashboardProvider =
    FutureProvider.family<PaymentsDashboard, PaymentsQuery>((ref, query) async {
  ref.keepAlive();
  final result = await ref.watch(adminRepositoryProvider).payments(
        q: query.q,
        planId: query.planId,
        status: query.status,
      );
  return PaymentsDashboard(payments: result.payments, totals: result.totals);
});

class ContactsQuery {
  const ContactsQuery({this.q = '', this.status});

  final String q;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is ContactsQuery && other.q == q && other.status == status;

  @override
  int get hashCode => Object.hash(q, status);
}

final contactsProvider =
    FutureProvider.family<List<ContactSubmission>, ContactsQuery>((ref, query) async {
  ref.keepAlive();
  return ref.watch(adminRepositoryProvider).contacts(
        q: query.q,
        status: query.status,
      );
});
