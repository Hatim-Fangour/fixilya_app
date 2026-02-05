abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection'])
    : super(message, 'NETWORK_FAILURE');
}

class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred'])
    : super(message, 'SERVER_FAILURE');
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication failed'])
    : super(message, 'AUTH_FAILURE');
}

class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Validation failed'])
    : super(message, 'VALIDATION_FAILURE');
}

class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred'])
    : super(message, 'CACHE_FAILURE');
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found'])
    : super(message, 'NOT_FOUND_FAILURE');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Unauthorized access'])
    : super(message, 'UNAUTHORIZED_FAILURE');
}
