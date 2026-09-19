import 'package:binance_spot_pro/core/api/api_exceptions.dart';

/// A minimal Result type so every repository/service method returns either
/// data or a typed [AppException] — never lets a raw exception or stack
/// trace leak up toward the UI layer.
sealed class Result<T> {
  const Result();

  factory Result.ok(T data) = Ok<T>;
  factory Result.err(AppException error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R when<R>({
    required R Function(T data) ok,
    required R Function(AppException error) err,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.data);
    if (self is Err<T>) return err(self.error);
    throw StateError('Unreachable');
  }
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final AppException error;
}
