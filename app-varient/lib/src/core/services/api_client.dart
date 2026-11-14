import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? url;
  final String? responseBody;

  ApiException(
    this.message, {
    this.statusCode,
    this.url,
    this.responseBody,
  });

  @override
  String toString() => 'ApiException: $message (statusCode: $statusCode, url: $url)';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.token,
    this.pharmacyCode = 'main',
    this.terminalHardwareId,
    this.terminalName,
  });

  String baseUrl;
  String? token;
  String pharmacyCode;
  String? terminalHardwareId;
  String? terminalName;

  void updateToken(String? newToken) {
    token = newToken;
  }

  void updateBaseUrl(String newBaseUrl) {
    baseUrl = newBaseUrl;
  }

  void updatePharmacyCode(String newPharmacyCode) {
    pharmacyCode = newPharmacyCode;
  }

  void updateTerminalInfo({String? hardwareId, String? name}) {
    terminalHardwareId = hardwareId;
    terminalName = name;
  }

  Uri _makeUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    var uri = Uri.parse('$baseUrl$cleanPath');
    // On Windows, subdomains of localhost (e.g. main.localhost) fail with 'No such host is known'.
    // Automatically rewrite *.localhost to localhost so Windows WinSock resolves to loopback 127.0.0.1.
    if (uri.host.contains('.localhost')) {
      uri = uri.replace(host: 'localhost');
    }
    return uri;
  }

  Map<String, String> _makeHeaders() {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri != null && baseUri.host.contains('.localhost')) {
      headers['Host'] = baseUri.hasPort ? '${baseUri.host}:${baseUri.port}' : baseUri.host;
    }
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (pharmacyCode.isNotEmpty) {
      headers['X-Pharmacy-Code'] = pharmacyCode;
    }
    if (terminalHardwareId != null && terminalHardwareId!.isNotEmpty) {
      headers['X-Terminal-Hardware-ID'] = terminalHardwareId!;
    }
    if (terminalName != null && terminalName!.isNotEmpty) {
      headers['X-Terminal-Name'] = terminalName!;
    }
    return headers;
  }

  Future<http.Response> get(String path) async {
    final uri = _makeUri(path);
    try {
      final response = await http
          .get(uri, headers: _makeHeaders())
          .timeout(const Duration(seconds: 15));
      return _checkResponse(response, uri.toString());
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the server at $uri. (OS error: ${e.osError?.message ?? e.message})',
        url: uri.toString(),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after 15s attempting to reach $uri.',
        url: uri.toString(),
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network client error: ${e.message}',
        url: uri.toString(),
      );
    }
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final uri = _makeUri(path);
    try {
      final response = await http
          .post(
            uri,
            headers: _makeHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _checkResponse(response, uri.toString());
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the server at $uri. (OS error: ${e.osError?.message ?? e.message})',
        url: uri.toString(),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after 15s attempting to reach $uri.',
        url: uri.toString(),
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network client error: ${e.message}',
        url: uri.toString(),
      );
    }
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final uri = _makeUri(path);
    try {
      final response = await http
          .put(
            uri,
            headers: _makeHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _checkResponse(response, uri.toString());
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the server at $uri. (OS error: ${e.osError?.message ?? e.message})',
        url: uri.toString(),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after 15s attempting to reach $uri.',
        url: uri.toString(),
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network client error: ${e.message}',
        url: uri.toString(),
      );
    }
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    final uri = _makeUri(path);
    try {
      final response = await http
          .patch(
            uri,
            headers: _makeHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _checkResponse(response, uri.toString());
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the server at $uri. (OS error: ${e.osError?.message ?? e.message})',
        url: uri.toString(),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after 15s attempting to reach $uri.',
        url: uri.toString(),
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network client error: ${e.message}',
        url: uri.toString(),
      );
    }
  }

  Future<http.Response> delete(String path) async {
    final uri = _makeUri(path);
    try {
      final response = await http
          .delete(uri, headers: _makeHeaders())
          .timeout(const Duration(seconds: 15));
      return _checkResponse(response, uri.toString());
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach the server at $uri. (OS error: ${e.osError?.message ?? e.message})',
        url: uri.toString(),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after 15s attempting to reach $uri.',
        url: uri.toString(),
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network client error: ${e.message}',
        url: uri.toString(),
      );
    }
  }

  http.Response _checkResponse(http.Response response, String url) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String message = 'Server returned error ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded.containsKey('message')) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw ApiException(
      message,
      statusCode: response.statusCode,
      url: url,
      responseBody: response.body,
    );
  }

  Stream<String> connectEvents() async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', _makeUri('/sync/events'));
      request.headers.addAll(_makeHeaders());
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      
      final streamedResponse = await client.send(request);
      
      if (streamedResponse.statusCode == 200) {
        final lineStream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
            
        await for (final line in lineStream) {
          if (line.startsWith('data:')) {
            yield line.substring(5).trim();
          }
        }
      }
    } catch (_) {
      // Allow stream to finish gracefully on failure
    } finally {
      client.close();
    }
  }
}
