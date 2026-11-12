import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/api_endpoint_policy.dart';

void main() {
  test('production permits HTTPS only', () {
    expect(ApiEndpointPolicy.validate('https://api.example.com', releaseMode: true).origin,
        'https://api.example.com');
    expect(() => ApiEndpointPolicy.validate('http://api.example.com', releaseMode: true),
        throwsFormatException);
  });

  test('local development can use a LAN HTTP endpoint', () {
    expect(ApiEndpointPolicy.validate('http://192.168.1.20:8000', releaseMode: false).port,
        8000);
  });

  test('rejects credentials, query parameters, routes and unsafe schemes', () {
    for (final url in [
      'https://user:pass@api.example.com',
      'https://api.example.com?token=abc',
      'https://api.example.com/other',
      'javascript:alert(1)',
      'https://api.example.com/#fragment',
    ]) {
      expect(() => ApiEndpointPolicy.validate(url, releaseMode: false),
          throwsFormatException, reason: url);
    }
  });
}
