import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_pro_admin/core/config/app_config.dart';

void main() {
  test('default API base points at local Nest admin prefix', () {
    expect(AppConfig.apiBase.endsWith('/api'), isTrue);
  });
}
