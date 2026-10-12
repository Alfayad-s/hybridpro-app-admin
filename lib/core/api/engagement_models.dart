class EngagementTemplate {
  const EngagementTemplate({
    required this.type,
    required this.title,
    required this.body,
    required this.enabled,
    required this.priority,
  });

  final String type;
  final String title;
  final String body;
  final bool enabled;
  final String priority;

  factory EngagementTemplate.fromJson(Map<String, dynamic> json) {
    return EngagementTemplate(
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      enabled: json['enabled'] != false,
      priority: (json['priority'] ?? 'LOW').toString(),
    );
  }

  String get label {
    final words = type.split('_').where((part) => part.isNotEmpty).map((part) {
      final lower = part.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    });
    return words.join(' ');
  }
}

class EngagementAdminConfig {
  const EngagementAdminConfig({
    required this.dailyLimit,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
    required this.templates,
  });

  final int dailyLimit;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final List<EngagementTemplate> templates;

  factory EngagementAdminConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['templates'];
    final templates = <EngagementTemplate>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          templates.add(EngagementTemplate.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return EngagementAdminConfig(
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 6,
      quietStartMinutes: (json['quietStartMinutes'] as num?)?.toInt() ?? (22 * 60 + 30),
      quietEndMinutes: (json['quietEndMinutes'] as num?)?.toInt() ?? (7 * 60),
      templates: templates,
    );
  }
}

String formatMinutes(int minutes) {
  final h24 = minutes.clamp(0, 1439) ~/ 60;
  final m = minutes.clamp(0, 1439) % 60;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final mm = m.toString().padLeft(2, '0');
  return '$h:$mm $suffix';
}
