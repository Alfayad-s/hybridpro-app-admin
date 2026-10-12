class AdminStats {
  const AdminStats({
    required this.total,
    required this.active,
    required this.expired,
    required this.expiringSoon,
    required this.byPlan,
    required this.paidOrders,
    required this.paidClients,
    required this.revenuePaise,
    required this.grantedOrders,
    required this.grantedPaise,
    this.trends = const AdminStatsTrends.empty(),
  });

  final int total;
  final int active;
  final int expired;
  final int expiringSoon;
  final Map<String, int> byPlan;
  final int paidOrders;
  final int paidClients;
  final int revenuePaise;
  final int grantedOrders;
  final int grantedPaise;
  final AdminStatsTrends trends;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['byPlan'];
    final byPlan = <String, int>{};
    if (rawPlan is Map) {
      for (final e in rawPlan.entries) {
        byPlan[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return AdminStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      expired: (json['expired'] as num?)?.toInt() ?? 0,
      expiringSoon: (json['expiringSoon'] as num?)?.toInt() ?? 0,
      byPlan: byPlan,
      paidOrders: (json['paidOrders'] as num?)?.toInt() ?? 0,
      paidClients: (json['paidClients'] as num?)?.toInt() ?? 0,
      revenuePaise: (json['revenuePaise'] as num?)?.toInt() ?? 0,
      grantedOrders: (json['grantedOrders'] as num?)?.toInt() ?? 0,
      grantedPaise: (json['grantedPaise'] as num?)?.toInt() ?? 0,
      trends: AdminStatsTrends.fromJson(
        json['trends'] is Map ? Map<String, dynamic>.from(json['trends'] as Map) : null,
      ),
    );
  }
}

class AdminStatsTrends {
  const AdminStatsTrends({
    required this.days,
    required this.revenuePaise,
    required this.paidOrders,
    required this.signups,
  });

  const AdminStatsTrends.empty()
      : days = const [],
        revenuePaise = const [],
        paidOrders = const [],
        signups = const [];

  final List<String> days;
  final List<int> revenuePaise;
  final List<int> paidOrders;
  final List<int> signups;

  factory AdminStatsTrends.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdminStatsTrends.empty();
    List<int> ints(dynamic raw) => (raw as List? ?? [])
        .map((e) => (e as num?)?.toInt() ?? 0)
        .toList();
    return AdminStatsTrends(
      days: (json['days'] as List? ?? []).map((e) => e.toString()).toList(),
      revenuePaise: ints(json['revenuePaise']),
      paidOrders: ints(json['paidOrders']),
      signups: ints(json['signups']),
    );
  }
}

class AdminClient {
  const AdminClient({
    required this.id,
    this.userId,
    required this.email,
    this.mobile,
    required this.planId,
    required this.planName,
    required this.status,
    this.startsAt,
    this.expiresAt,
    this.daysRemaining,
    this.nextPlanId,
    this.fullName,
    this.avatarUrl,
    required this.appLinked,
    this.paymentCount = 0,
    this.totalPaidPaise = 0,
    this.grantCount = 0,
    this.totalGrantedPaise = 0,
    this.lastAmountPaise = 0,
    this.lastPaidAt,
    this.expiringSoon = false,
  });

  final String id;
  final String? userId;
  final String email;
  final String? mobile;
  final String planId;
  final String planName;
  final String status;
  final String? startsAt;
  final String? expiresAt;
  final int? daysRemaining;
  final String? nextPlanId;
  final String? fullName;
  final String? avatarUrl;
  final bool appLinked;
  final int paymentCount;
  final int totalPaidPaise;
  final int grantCount;
  final int totalGrantedPaise;
  final int lastAmountPaise;
  final String? lastPaidAt;
  final bool expiringSoon;

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName!.trim() : email;

  factory AdminClient.fromJson(Map<String, dynamic> json) {
    return AdminClient(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String?,
      planId: json['planId'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startsAt: json['startsAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      nextPlanId: json['nextPlanId'] as String?,
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      appLinked: json['appLinked'] == true,
      paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 0,
      totalPaidPaise: (json['totalPaidPaise'] as num?)?.toInt() ?? 0,
      grantCount: (json['grantCount'] as num?)?.toInt() ?? 0,
      totalGrantedPaise: (json['totalGrantedPaise'] as num?)?.toInt() ?? 0,
      lastAmountPaise: (json['lastAmountPaise'] as num?)?.toInt() ?? 0,
      lastPaidAt: json['lastPaidAt'] as String?,
      expiringSoon: json['expiringSoon'] == true,
    );
  }
}

class AdminPayment {
  const AdminPayment({
    required this.id,
    this.subscriptionId,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.planId,
    required this.planName,
    required this.amountPaise,
    required this.currency,
    this.pineOrderId,
    required this.status,
    required this.paidAt,
  });

  final String id;
  final String? subscriptionId;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String planId;
  final String planName;
  final int amountPaise;
  final String currency;
  final String? pineOrderId;
  final String status;
  final String paidAt;

  factory AdminPayment.fromJson(Map<String, dynamic> json) {
    return AdminPayment(
      id: json['id'] as String,
      subscriptionId: json['subscriptionId'] as String?,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      planId: json['planId'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      pineOrderId: json['pineOrderId'] as String?,
      status: json['status'] as String? ?? '',
      paidAt: json['paidAt'] as String? ?? '',
    );
  }
}

class PaymentTotals {
  const PaymentTotals({
    required this.collectedPaise,
    required this.grantedPaise,
    required this.orderCount,
    required this.uniquePayers,
  });

  final int collectedPaise;
  final int grantedPaise;
  final int orderCount;
  final int uniquePayers;

  factory PaymentTotals.fromJson(Map<String, dynamic> json) {
    return PaymentTotals(
      collectedPaise: (json['collectedPaise'] as num?)?.toInt() ?? 0,
      grantedPaise: (json['grantedPaise'] as num?)?.toInt() ?? 0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      uniquePayers: (json['uniquePayers'] as num?)?.toInt() ?? 0,
    );
  }
}

class SubscriptionEvent {
  const SubscriptionEvent({
    required this.id,
    required this.action,
    required this.planId,
    required this.planName,
    this.startsAt,
    this.expiresAt,
    this.amountPaise,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String planId;
  final String planName;
  final String? startsAt;
  final String? expiresAt;
  final int? amountPaise;
  final String createdAt;

  factory SubscriptionEvent.fromJson(Map<String, dynamic> json) {
    return SubscriptionEvent(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      startsAt: json['startsAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      amountPaise: (json['amountPaise'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class Checkin {
  const Checkin({
    required this.id,
    required this.checkinDate,
    this.weight,
    this.adherence,
    this.clientUpdate,
    this.coachReply,
    required this.createdAt,
  });

  final String id;
  final String checkinDate;
  final String? weight;
  final String? adherence;
  final String? clientUpdate;
  final String? coachReply;
  final String createdAt;

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'] as String,
      checkinDate: json['checkinDate'] as String? ?? '',
      weight: json['weight'] as String?,
      adherence: json['adherence'] as String?,
      clientUpdate: json['clientUpdate'] as String?,
      coachReply: json['coachReply'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AssignedPlan {
  const AssignedPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.assignedByCoach,
    required this.createdAt,
    required this.updatedAt,
    required this.days,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool assignedByCoach;
  final String createdAt;
  final String updatedAt;
  final List<AssignedPlanDay> days;

  factory AssignedPlan.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedPlanDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AssignedPlan(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] == true,
      assignedByCoach: json['assignedByCoach'] == true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      days: days,
    );
  }
}

class AssignedPlanDay {
  const AssignedPlanDay({
    required this.dayOfWeek,
    required this.name,
    required this.muscleFocus,
    required this.isRestDay,
    required this.exercises,
  });

  final int dayOfWeek;
  final String name;
  final String muscleFocus;
  final bool isRestDay;
  final List<AssignedPlanExercise> exercises;

  factory AssignedPlanDay.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedPlanExercise.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AssignedPlanDay(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      muscleFocus: json['muscleFocus'] as String? ?? '',
      isRestDay: json['isRestDay'] == true,
      exercises: exercises,
    );
  }
}

class AssignedPlanExercise {
  const AssignedPlanExercise({
    required this.name,
    required this.targetSets,
    required this.targetReps,
    this.exerciseId,
    this.restSeconds = 90,
    this.targetRpe,
    this.targetRir,
  });

  final String? exerciseId;
  final String name;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final int? targetRpe;
  final int? targetRir;

  factory AssignedPlanExercise.fromJson(Map<String, dynamic> json) {
    return AssignedPlanExercise(
      exerciseId: json['exerciseId'] as String?,
      name: json['name'] as String? ?? '',
      targetSets: (json['targetSets'] as num?)?.toInt() ?? 0,
      targetReps: (json['targetReps'] as num?)?.toInt() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      targetRpe: _bounded(json['targetRpe'], 1, 10),
      targetRir: _bounded(json['targetRir'], 0, 10),
    );
  }
}

class ClientDetail {
  const ClientDetail({
    required this.subscription,
    required this.events,
    required this.payments,
    required this.notes,
    this.notesUpdatedAt,
    required this.checkins,
    required this.assignedPlans,
    this.assignedMealPlans = const [],
    this.assignedWaterChallenges = const [],
    this.progressPhotos = const [],
  });

  final AdminClient subscription;
  final List<SubscriptionEvent> events;
  final List<AdminPayment> payments;
  final String notes;
  final String? notesUpdatedAt;
  final List<Checkin> checkins;
  final List<AssignedPlan> assignedPlans;
  final List<AssignedMealPlan> assignedMealPlans;
  final List<AssignedWaterChallenge> assignedWaterChallenges;
  final List<ClientProgressPhoto> progressPhotos;

  factory ClientDetail.fromJson(Map<String, dynamic> json) {
    final subRaw = json['subscription'];
    final subMap = subRaw is Map
        ? Map<String, dynamic>.from(subRaw)
        : Map<String, dynamic>.from(json);
    final events = (json['events'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SubscriptionEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final payments = (json['payments'] as List? ?? [])
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          return AdminPayment(
            id: m['id'] as String? ?? '',
            subscriptionId: m['subscriptionId'] as String?,
            email: subMap['email'] as String? ?? '',
            planId: m['planId'] as String? ?? '',
            planName: m['planName'] as String? ?? m['planId'] as String? ?? '',
            amountPaise: (m['amountPaise'] as num?)?.toInt() ?? 0,
            currency: m['currency'] as String? ?? 'INR',
            pineOrderId: m['pineOrderId'] as String?,
            status: m['status'] as String? ?? '',
            paidAt: m['paidAt'] as String? ?? '',
          );
        })
        .toList();
    final checkins = (json['checkins'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Checkin.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final assigned = (json['assignedPlans'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final mealPlans = (json['assignedMealPlans'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedMealPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final water = (json['assignedWaterChallenges'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedWaterChallenge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final photos = (json['progressPhotos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ClientProgressPhoto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ClientDetail(
      subscription: AdminClient.fromJson(subMap),
      events: events,
      payments: payments,
      notes: json['notes'] as String? ?? '',
      notesUpdatedAt: json['notesUpdatedAt'] as String?,
      checkins: checkins,
      assignedPlans: assigned,
      assignedMealPlans: mealPlans,
      assignedWaterChallenges: water,
      progressPhotos: photos,
    );
  }
}

class ClientProgressPhoto {
  const ClientProgressPhoto({
    required this.id,
    required this.day,
    required this.pose,
    required this.url,
  });

  final String id;
  final String day;
  final String pose;
  final String url;

  factory ClientProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ClientProgressPhoto(
      id: json['id']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      pose: json['pose']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class AssignedMealPlan {
  const AssignedMealPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.assignedByCoach,
    required this.createdAt,
    required this.updatedAt,
    required this.days,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool assignedByCoach;
  final String createdAt;
  final String updatedAt;
  final List<AssignedMealPlanDay> days;

  int get mealCount =>
      days.fold(0, (n, d) => n + d.meals.length);

  factory AssignedMealPlan.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedMealPlanDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AssignedMealPlan(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] == true,
      assignedByCoach: json['assignedByCoach'] == true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      days: days,
    );
  }
}

class AssignedMealPlanDay {
  const AssignedMealPlanDay({
    required this.dayOfWeek,
    required this.meals,
  });

  final int dayOfWeek;
  final List<AssignedMealSlot> meals;

  factory AssignedMealPlanDay.fromJson(Map<String, dynamic> json) {
    final meals = (json['meals'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AssignedMealSlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return AssignedMealPlanDay(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      meals: meals,
    );
  }
}

class AssignedMealSlot {
  const AssignedMealSlot({
    required this.id,
    required this.type,
    required this.name,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.notes,
    this.imageUrl,
  });

  final String id;
  final String type;
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String? notes;
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory AssignedMealSlot.fromJson(Map<String, dynamic> json) {
    return AssignedMealSlot(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'breakfast').toString(),
      name: (json['name'] ?? '').toString(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (json['fatG'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class AssignedWaterChallenge {
  const AssignedWaterChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetMlPerDay,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.assignedByCoach,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final int targetMlPerDay;
  final int durationDays;
  final String startDate;
  final String endDate;
  final bool isActive;
  final bool assignedByCoach;
  final String createdAt;
  final String updatedAt;

  factory AssignedWaterChallenge.fromJson(Map<String, dynamic> json) {
    return AssignedWaterChallenge(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      targetMlPerDay: (json['targetMlPerDay'] as num?)?.toInt() ?? 3000,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      isActive: json['isActive'] == true,
      assignedByCoach: json['assignedByCoach'] == true,
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

class Exercise {
  const Exercise({
    required this.uuid,
    required this.id,
    required this.slug,
    required this.name,
    required this.muscleGroup,
    required this.target,
    required this.secondary,
    required this.equipment,
    required this.difficulty,
    this.imageUrl,
    this.videoUrl,
    required this.instructions,
    this.description,
  });

  final String uuid;
  final String id;
  final String slug;
  final String name;
  final String muscleGroup;
  final String target;
  final List<String> secondary;
  final String equipment;
  final String difficulty;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> instructions;
  final String? description;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      uuid: json['uuid'] as String? ?? json['id'] as String? ?? '',
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? '',
      target: json['target'] as String? ?? '',
      secondary: (json['secondary'] as List? ?? []).map((e) => e.toString()).toList(),
      equipment: json['equipment'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      instructions: (json['instructions'] as List? ?? []).map((e) => e.toString()).toList(),
      description: json['description'] as String?,
    );
  }
}

/// A reusable meal in the coach's meal library.
class LibraryMeal {
  const LibraryMeal({
    required this.id,
    required this.name,
    required this.type,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.notes,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String type;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String? notes;
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory LibraryMeal.fromJson(Map<String, dynamic> json) {
    return LibraryMeal(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'lunch').toString(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (json['fatG'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class ContactSubmission {
  const ContactSubmission({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.goal,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String goal;
  final String status;
  final String createdAt;

  factory ContactSubmission.fromJson(Map<String, dynamic> json) {
    return ContactSubmission(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ContactDetail {
  const ContactDetail({
    required this.submission,
    this.clientId,
    this.clientStatus,
    this.clientPlan,
  });

  final ContactSubmission submission;
  final String? clientId;
  final String? clientStatus;
  final String? clientPlan;

  factory ContactDetail.fromJson(Map<String, dynamic> json) {
    return ContactDetail(
      submission: ContactSubmission.fromJson(
        Map<String, dynamic>.from(json['submission'] as Map),
      ),
      clientId: json['clientId'] as String?,
      clientStatus: json['clientStatus'] as String?,
      clientPlan: json['clientPlan'] as String?,
    );
  }
}

const planIds = ['foundation', 'performance', 'elite'];

class StoreTaxonomyAdmin {
  const StoreTaxonomyAdmin({
    required this.id,
    required this.slug,
    required this.label,
    required this.sortOrder,
    required this.active,
    this.comingSoon = false,
  });

  final String id;
  final String slug;
  final String label;
  final int sortOrder;
  final bool active;
  final bool comingSoon;

  factory StoreTaxonomyAdmin.fromJson(Map<String, dynamic> json) {
    return StoreTaxonomyAdmin(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
      comingSoon: json['comingSoon'] == true,
    );
  }
}

class ShopOrderItemAdmin {
  const ShopOrderItemAdmin({
    required this.slug,
    required this.title,
    required this.size,
    required this.qty,
    required this.unitPaise,
    required this.image,
    required this.stockOut,
  });

  final String slug;
  final String title;
  final String size;
  final int qty;
  final int unitPaise;
  final String image;
  final bool stockOut;

  int get linePaise => stockOut || qty < 1 ? 0 : unitPaise * qty;

  String get amountLabel => formatOrderRupees(linePaise);

  ShopOrderItemAdmin copyWith({int? qty, bool? stockOut}) {
    return ShopOrderItemAdmin(
      slug: slug,
      title: title,
      size: size,
      qty: qty ?? this.qty,
      unitPaise: unitPaise,
      image: image,
      stockOut: stockOut ?? this.stockOut,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'size': size,
      'qty': qty,
      'unitPaise': unitPaise,
      'image': image,
      'stockOut': stockOut,
    };
  }

  factory ShopOrderItemAdmin.fromJson(Map<String, dynamic> json) {
    final qty = (json['qty'] as num?)?.toInt() ?? 1;
    final paise = (json['paise'] as num?)?.toInt() ?? 0;
    final unit = (json['unitPaise'] as num?)?.toInt();
    return ShopOrderItemAdmin(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? 'Item').toString(),
      size: (json['size'] ?? '').toString(),
      qty: qty,
      unitPaise: unit ?? (qty > 0 ? (paise / qty).round() : paise),
      image: (json['image'] ?? '').toString(),
      stockOut: json['stockOut'] == true || qty < 1,
    );
  }
}

String formatOrderRupees(int paise) {
  final rupees = paise / 100;
  final text = paise % 100 == 0 ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2);
  return '₹$text';
}

class ShopOrderAdmin {
  const ShopOrderAdmin({
    required this.id,
    required this.reference,
    required this.status,
    required this.customerName,
    required this.email,
    required this.mobile,
    required this.floor,
    required this.address,
    required this.city,
    required this.pincode,
    required this.items,
    required this.amountPaise,
    required this.createdAt,
    this.rejectReason = '',
  });

  final String id;
  final String reference;
  final String status;
  final String customerName;
  final String email;
  final String mobile;
  final String floor;
  final String address;
  final String city;
  final String pincode;
  final List<ShopOrderItemAdmin> items;
  final int amountPaise;
  final String createdAt;
  final String rejectReason;

  int get totalPaise =>
      items.fold(0, (sum, item) => sum + item.linePaise);

  String get amountLabel =>
      formatOrderRupees(items.isEmpty ? amountPaise : totalPaise);

  bool get canEdit => status == 'pending' || status == 'paid';

  String get deliveryLine {
    return [
      floor,
      address,
      [city, pincode].where((part) => part.trim().isNotEmpty).join(' '),
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  factory ShopOrderAdmin.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return ShopOrderAdmin(
      id: (json['id'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      floor: (json['floor'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      items: rawItems
          .map((item) => ShopOrderItemAdmin.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] ?? '').toString(),
      rejectReason: (json['rejectReason'] ?? '').toString(),
    );
  }
}

class ShopPromoAdmin {
  const ShopPromoAdmin({
    required this.id,
    required this.placement,
    required this.imageUrl,
    required this.alt,
    required this.label,
    required this.category,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String placement;
  final String imageUrl;
  final String alt;
  final String label;
  final String category;
  final bool active;
  final int sortOrder;

  factory ShopPromoAdmin.fromJson(Map<String, dynamic> json) {
    return ShopPromoAdmin(
      id: (json['id'] ?? '').toString(),
      placement: (json['placement'] ?? 'banner').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      alt: (json['alt'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      active: json['active'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoreProductAdmin {
  const StoreProductAdmin({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    this.description,
    required this.category,
    required this.kind,
    required this.priceLabel,
    this.pricePaise,
    this.imageUrl,
    this.sizes = const [],
    this.planId,
    required this.active,
    this.comingSoon = false,
    required this.sortOrder,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String? description;
  final String category;
  final String kind;
  final String priceLabel;
  final int? pricePaise;
  final String? imageUrl;
  final List<String> sizes;
  final String? planId;
  final bool active;
  final bool comingSoon;
  final int sortOrder;

  bool get isPlan => kind == 'plan';
  bool get isMerch => kind == 'merch';

  factory StoreProductAdmin.fromJson(Map<String, dynamic> json) {
    return StoreProductAdmin(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      description: json['description']?.toString(),
      category: (json['category'] ?? 'tees').toString(),
      kind: (json['kind'] ?? 'merch').toString(),
      priceLabel: (json['priceLabel'] ?? '').toString(),
      pricePaise: (json['pricePaise'] as num?)?.toInt(),
      imageUrl: json['imageUrl']?.toString(),
      sizes: (json['sizes'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      planId: json['planId']?.toString(),
      active: json['active'] != false,
      comingSoon: json['comingSoon'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

int? _bounded(dynamic raw, int min, int max) {
  final n = (raw as num?)?.toInt();
  if (n == null || n < min || n > max) return null;
  return n;
}
