import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack_mobile/core/config/app_config.dart';

void main() {
  test('env defines loaded', () {
    // ignore: avoid_print
    print('tenant=${AppConfig.entraTenantId} client=${AppConfig.entraClientId} aud=${AppConfig.apiAudience} scope=${AppConfig.worktrackScope} configured=${AppConfig.isConfigured}');
    expect(AppConfig.isConfigured, isTrue);
  });
}
