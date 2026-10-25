import '../strings/app_strings.dart';

/// Result type for the service boundary (AGENTS.md: errors reach the UI
/// as state, not exceptions).
///
/// Services return [Result]; controllers convert a [Failure] into a
/// string key for the view; views never see raw exceptions.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    final Result<T> self = this;
    if (self is Success<T>) {
      return onSuccess(self.value);
    }
    return onFailure((self as Failure<T>).failure);
  }

  Result<U> map<U>(U Function(T value) transform) {
    final Result<T> self = this;
    if (self is Success<T>) {
      return Success<U>(transform(self.value));
    }
    return Failure<U>((self as Failure<T>).failure);
  }
}

/// Successful result carrying [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// Failed result carrying an [AppFailure]. The failure holds a string
/// key, never exception text.
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}

/// User-facing failure: a key into [AppStrings] plus an optional machine
/// code for logging. No exception message, stack trace or photo content
/// is ever stored here.
class AppFailure {
  const AppFailure({required this.messageKey, this.code});

  /// Key into [AppStrings], resolved with [AppStrings.tr].
  final String messageKey;

  /// Machine-readable code (e.g. for logs). Never shown to users.
  final String? code;

  /// Resolved user-facing message for the key.
  String get userMessage => AppStrings.tr(messageKey);

  /// Fallback failure for unexpected errors. Callers should prefer a
  /// specific key; this exists so no raw error ever reaches a view.
  static AppFailure unknown() {
    return const AppFailure(messageKey: AppStrings.errorGeneric);
  }
}
