import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Signs Binance "SIGNED" endpoint query strings with HMAC-SHA256, per
/// https://developers.binance.com/docs/binance-spot-api-docs/rest-api#signed-endpoint-parameters
///
/// This is the ONLY place in the codebase allowed to touch the raw API
/// secret value. [BinanceRestClient] pulls the secret from
/// [SecureCredentialsStore] right before a signed call, passes it here,
/// and discards the local reference immediately after — the secret is
/// never stored in a field, never logged, never included in exceptions.
class BinanceRequestSigner {
  const BinanceRequestSigner._();

  static String sign({
    required String queryString,
    required String apiSecret,
  }) {
    final key = utf8.encode(apiSecret);
    final bytes = utf8.encode(queryString);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }
}
