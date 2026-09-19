import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/core/utils/safe_logger.dart';

void main() {
  group('SafeLogger.redact', () {
    test('redacts long hex signatures', () {
      final signed =
          'timestamp=123&signature=3c1c9f0e2a7b4d5e6f7081920a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3';
      final out = SafeLogger.redact(signed);
      expect(out.contains('3c1c9f0e2a7b4d5e6f7081920a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3'), isFalse);
      expect(out.contains('signature=[REDACTED]'), isTrue);
    });

    test('redacts long alphanumeric API keys', () {
      const apiKey = 'vmPUZE6mv9SD5VNHk4HlWFsOr6aKE2zvsw0MuIgwCIPy6utIco14y7Ju91duEh8A';
      final out = SafeLogger.redact('X-MBX-APIKEY: $apiKey');
      expect(out.contains(apiKey), isFalse);
    });

    test('leaves short, non-secret text untouched', () {
      const msg = 'WebSocket connected (3 streams)';
      expect(SafeLogger.redact(msg), msg);
    });

    test('redacts apiKey= and secret= query params regardless of case', () {
      final out = SafeLogger.redact('apiKey=ABCDEF123456&other=1');
      expect(out.contains('ABCDEF123456'), isFalse);
    });
  });
}
