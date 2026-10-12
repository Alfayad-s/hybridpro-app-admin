class GymSession {
  const GymSession({
    required this.sessionId,
    required this.subscriptionId,
    required this.userId,
    required this.email,
    this.fullName,
    required this.checkedInAt,
    this.checkedOutAt,
    required this.status,
  });

  final String sessionId;
  final String subscriptionId;
  final String userId;
  final String email;
  final String? fullName;
  final String checkedInAt;
  final String? checkedOutAt;
  final String status;

  factory GymSession.fromJson(Map<String, dynamic> json) {
    return GymSession(
      sessionId: (json['sessionId'] ?? json['id'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: json['fullName']?.toString(),
      checkedInAt: (json['checkedInAt'] ?? '').toString(),
      checkedOutAt: json['checkedOutAt']?.toString(),
      status: (json['status'] ?? 'closed').toString(),
    );
  }

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return 'Member';
  }
}
