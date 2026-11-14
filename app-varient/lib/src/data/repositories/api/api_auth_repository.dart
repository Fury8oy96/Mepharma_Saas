import 'dart:convert';
import 'dart:io';

import '../../../data/db/enums.dart';
import '../../../domain/exceptions/auth_exception.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_config_manager.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client, this._configManager, {this.onTokenUpdated});

  final ApiClient _client;
  final ApiConfigManager _configManager;
  final void Function(String)? onTokenUpdated;

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.post('/auth/login', body: {
        'username': username,
        'password': password,
      });

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw AuthException.dataParsingError(
          details: 'Failed to decode JSON response from server: ${response.body}',
          endpoint: '${_client.baseUrl}/auth/login',
        );
      }

      final token = data['token'] as String?;
      final userJson = data['user'] as Map<String, dynamic>?;

      if (token == null || userJson == null) {
        throw AuthException.dataParsingError(
          details: 'Response is missing "token" or "user" object. Keys present: ${data.keys.toList()}',
          endpoint: '${_client.baseUrl}/auth/login',
        );
      }

      // Save token in local client config
      final currentConfig = await _configManager.loadConfig();
      await _configManager.saveConfig(currentConfig.copyWith(token: token));

      // Notify Riverpod state notifier reactively
      onTokenUpdated?.call(token);

      final roleStr = (userJson['role'] as String? ?? '').toLowerCase();
      final mappedRole = (roleStr == 'super_admin' || roleStr == 'superadmin')
          ? UserRole.superAdmin
          : (roleStr == 'pharmacy_admin' ||
                  roleStr == 'pharmacyadmin')
              ? UserRole.pharmacyAdmin
              : (roleStr == 'branch_admin' ||
                      roleStr == 'branchadmin')
                  ? UserRole.branchAdmin
              : (roleStr == 'supervisor')
                  ? UserRole.supervisor
                  : (roleStr == 'pharmacist')
                      ? UserRole.pharmacist
                      : (roleStr == 'admin')
                          ? UserRole.admin
                          : UserRole.staff;

      final rawId = userJson['id'];
      final userId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;

      final isActiveRaw = userJson['isActive'] ?? userJson['is_active'];
      final isActive = isActiveRaw is bool ? isActiveRaw : (isActiveRaw?.toString() == 'true' || isActiveRaw == 1);

      final createdAtRaw = userJson['createdAt'] ?? userJson['created_at'];
      final createdAt = DateTime.tryParse(createdAtRaw?.toString() ?? '') ?? DateTime.now();

      final branchIdRaw = userJson['branchId'] ?? userJson['branch_id'] ?? userJson['pharmacyId'] ?? userJson['pharmacy_id'];
      final branchId = branchIdRaw is int ? branchIdRaw : int.tryParse(branchIdRaw?.toString() ?? '1') ?? 1;

      return AppUser(
        id: userId,
        username: userJson['username'] as String? ?? username,
        role: mappedRole,
        isActive: isActive,
        createdAt: createdAt,
        branchId: branchId,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw AuthException.invalidCredentials(
          message: e.message,
          details: 'Status: 401 Unauthorized from ${e.url}',
          endpoint: e.url,
        );
      }
      if (e.statusCode == 403) {
        throw AuthException.accountDeactivated(
          message: e.message,
          details: 'Status: 403 Forbidden from ${e.url}',
          endpoint: e.url,
        );
      }
      if (e.statusCode == 404) {
        throw AuthException.serverError(
          statusCode: 404,
          message: 'Endpoint ${e.url} not found (404). Please verify backend baseUrl configuration.',
          endpoint: e.url,
          details: e.responseBody,
        );
      }
      if (e.statusCode != null && e.statusCode! >= 500) {
        throw AuthException.serverError(
          statusCode: e.statusCode!,
          message: e.message,
          endpoint: e.url,
          details: e.responseBody,
        );
      }
      if (e.message.contains('Cannot reach the server') || e.message.contains('SocketException')) {
        throw AuthException.serverUnreachable(
          endpoint: e.url ?? _client.baseUrl,
          details: e.message,
        );
      }
      if (e.message.contains('timed out')) {
        throw AuthException.timeout(
          endpoint: e.url ?? _client.baseUrl,
          details: e.message,
        );
      }
      throw AuthException.unknown(
        message: e.message,
        details: 'Status: ${e.statusCode} | URL: ${e.url} | Body: ${e.responseBody}',
        endpoint: e.url,
      );
    } on SocketException catch (e) {
      throw AuthException.serverUnreachable(
        endpoint: _client.baseUrl,
        details: 'OS Error: ${e.osError?.message ?? e.message}',
      );
    } on AuthException {
      rethrow;
    } catch (e, stack) {
      throw AuthException.unknown(
        message: e.toString(),
        details: 'Type: ${e.runtimeType}\nStack: $stack',
        endpoint: _client.baseUrl,
      );
    }
  }
}
