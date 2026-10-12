class CoachWindow {
  const CoachWindow({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });

  final int weekday;
  final int startMinute;
  final int endMinute;

  factory CoachWindow.fromJson(Map<String, dynamic> json) {
    return CoachWindow(
      weekday: json['weekday'] as int? ?? 0,
      startMinute: json['startMinute'] as int? ?? 0,
      endMinute: json['endMinute'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'startMinute': startMinute,
        'endMinute': endMinute,
      };
}

class CoachTimeOff {
  const CoachTimeOff({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  factory CoachTimeOff.fromJson(Map<String, dynamic> json) {
    return CoachTimeOff(
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
      };
}

class CoachAvailability {
  const CoachAvailability({required this.windows, required this.timeOff});

  final List<CoachWindow> windows;
  final List<CoachTimeOff> timeOff;

  factory CoachAvailability.fromJson(Map<String, dynamic> json) {
    final windows = json['windows'];
    final timeOff = json['timeOff'];
    return CoachAvailability(
      windows: windows is List
          ? [
              for (final item in windows)
                if (item is Map<String, dynamic>) CoachWindow.fromJson(item),
            ]
          : const [],
      timeOff: timeOff is List
          ? [
              for (final item in timeOff)
                if (item is Map<String, dynamic>) CoachTimeOff.fromJson(item),
            ]
          : const [],
    );
  }
}

class SessionSlot {
  const SessionSlot({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  factory SessionSlot.fromJson(Map<String, dynamic> json) {
    return SessionSlot(
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
    );
  }
}

class CoachSession {
  const CoachSession({
    required this.id,
    required this.subscriptionId,
    required this.email,
    required this.fullName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.bookedBy,
  });

  final String id;
  final String subscriptionId;
  final String email;
  final String? fullName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String bookedBy;

  bool get upcoming =>
      status == 'booked' && endsAt.isAfter(DateTime.now());

  factory CoachSession.fromJson(Map<String, dynamic> json) {
    return CoachSession(
      id: json['id'] as String? ?? '',
      subscriptionId: json['subscriptionId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String?,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String? ?? 'booked',
      bookedBy: json['bookedBy'] as String? ?? 'member',
    );
  }
}

const istOffset = Duration(hours: 5, minutes: 30);

DateTime toIst(DateTime instant) => instant.toUtc().add(istOffset);

String formatSessionWhen(DateTime instant) {
  final ist = toIst(instant);
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  final suffix = ist.hour < 12 ? 'AM' : 'PM';
  final minute = ist.minute.toString().padLeft(2, '0');
  return '${days[ist.weekday % 7]} ${ist.day} ${months[ist.month - 1]} · $hour:$minute $suffix';
}

String formatHourMinute(int minute) {
  final hour24 = minute ~/ 60;
  if (hour24 == 24) return '12:00 AM';
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour:00 $suffix';
}

String istDayKey(DateTime instant) {
  final ist = toIst(instant);
  final month = ist.month.toString().padLeft(2, '0');
  final day = ist.day.toString().padLeft(2, '0');
  return '${ist.year}-$month-$day';
}

String istDayLabel(DateTime instant) {
  final ist = toIst(instant);
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[ist.weekday % 7]}, ${ist.day} ${months[ist.month - 1]}';
}
