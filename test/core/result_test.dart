import 'package:flutter_test/flutter_test.dart';
import 'package:binance_spot_pro/core/api/api_exceptions.dart';
import 'package:binance_spot_pro/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Ok carries data and isOk is true', () {
      const result = Result<int>.ok(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      final value = result.when(ok: (d) => d, err: (_) => -1);
      expect(value, 42);
    });

    test('Err carries an AppException and isErr is true', () {
      const result = Result<int>.err(NetworkException());
      expect(result.isErr, isTrue);
      final message = result.when(ok: (_) => '', err: (e) => e.userMessage);
      expect(message, contains('Network error'));
    });

    test('mapBinanceErrorCode maps known codes to typed exceptions', () {
      expect(mapBinanceErrorCode(-1003, null), isA<RateLimitException>());
      expect(mapBinanceErrorCode(-2015, null), isA<InvalidApiKeyException>());
      expect(mapBinanceErrorCode(-2010, null), isA<InsufficientBalanceException>());
      expect(mapBinanceErrorCode(-9999, 'weird'), isA<UnknownApiException>());
    });
  });
}
