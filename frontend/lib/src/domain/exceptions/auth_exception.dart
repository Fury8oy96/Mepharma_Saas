enum AuthErrorType {
  invalidCredentials,
  accountDeactivated,
  serverUnreachable,
  timeout,
  serverError,
  dataParsingError,
  unknown,
}

class AuthException implements Exception {
  final AuthErrorType type;
  final String message;
  final String? technicalDetails;
  final int? statusCode;
  final String? endpoint;

  const AuthException({
    required this.type,
    required this.message,
    this.technicalDetails,
    this.statusCode,
    this.endpoint,
  });

  factory AuthException.invalidCredentials({String? message, String? details, String? endpoint}) =>
      AuthException(
        type: AuthErrorType.invalidCredentials,
        message: message ?? 'Invalid username or password.',
        technicalDetails: details,
        statusCode: 401,
        endpoint: endpoint,
      );

  factory AuthException.accountDeactivated({String? message, String? details, String? endpoint}) =>
      AuthException(
        type: AuthErrorType.accountDeactivated,
        message: message ?? 'This user account is currently deactivated.',
        technicalDetails: details,
        statusCode: 403,
        endpoint: endpoint,
      );

  factory AuthException.serverUnreachable({
    required String endpoint,
    String? details,
  }) =>
      AuthException(
        type: AuthErrorType.serverUnreachable,
        message: 'Cannot reach server at $endpoint. Please verify that the backend is running.',
        technicalDetails: details,
        endpoint: endpoint,
      );

  factory AuthException.timeout({required String endpoint, String? details}) =>
      AuthException(
        type: AuthErrorType.timeout,
        message: 'Connection timed out while contacting server.',
        technicalDetails: details,
        endpoint: endpoint,
      );

  factory AuthException.serverError({
    required int statusCode,
    required String message,
    String? endpoint,
    String? details,
  }) =>
      AuthException(
        type: AuthErrorType.serverError,
        message: 'Server Error ($statusCode): $message',
        technicalDetails: details,
        statusCode: statusCode,
        endpoint: endpoint,
      );

  factory AuthException.dataParsingError({
    required String details,
    String? endpoint,
  }) =>
      AuthException(
        type: AuthErrorType.dataParsingError,
        message: 'Response payload structure mismatch.',
        technicalDetails: details,
        endpoint: endpoint,
      );

  factory AuthException.unknown({required String message, String? details, String? endpoint}) =>
      AuthException(
        type: AuthErrorType.unknown,
        message: message,
        technicalDetails: details,
        endpoint: endpoint,
      );

  @override
  String toString() => 'AuthException($type, message: "$message", status: $statusCode, endpoint: "$endpoint", details: "$technicalDetails")';
}
