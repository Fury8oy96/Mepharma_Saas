import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/api_client.dart';
import '../../domain/models/api_config.dart';

class SupervisorApprovalDialog extends ConsumerStatefulWidget {
  const SupervisorApprovalDialog({
    super.key,
    required this.reason,
  });

  final String reason;

  static Future<bool> requestApproval(BuildContext context, {required String reason}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SupervisorApprovalDialog(reason: reason),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SupervisorApprovalDialog> createState() => _SupervisorApprovalDialogState();
}

class _SupervisorApprovalDialogState extends ConsumerState<SupervisorApprovalDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter supervisor password or PIN.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final config = ref.read(apiConfigProvider);

      if (config.mode == DatabaseMode.onlineApi) {
        final client = ref.read(apiClientProvider);
        final response = await client.post('/auth/verify-supervisor', body: {
          'username': username.isNotEmpty ? username : null,
          'password': password,
        });

        if (response.statusCode == 200) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        } else {
          setState(() {
            _errorMessage = 'Invalid supervisor credentials or insufficient permissions.';
            _loading = false;
          });
        }
      } else {
        // Offline / Local SQLite verification
        final userRepo = ref.read(userRepositoryProvider);
        final user = await userRepo.findByUsername(username.isNotEmpty ? username : 'admin');
        if (user != null && user.canAuthorizeSupervisor) {
          final authRepo = ref.read(authRepositoryProvider);
          final logged = await authRepo.login(username: user.username, password: password);
          if (logged != null) {
            if (mounted) Navigator.of(context).pop(true);
            return;
          }
        }
        setState(() {
          _errorMessage = 'Invalid local supervisor password.';
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Authorization failed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.orange, size: 28),
          const SizedBox(width: 10),
          const Text('Supervisor Authorization'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.reason,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Supervisor Username (optional)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Supervisor Password / PIN *',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Authorize'),
        ),
      ],
    );
  }
}
