import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/db/enums.dart';
import '../../domain/models/app_user.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  Future<void> _addUser(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(sessionProvider);
    final isSuperAdmin = current?.isSuperAdmin == true;

    final result = await showDialog<_UserResult>(
      context: context,
      builder: (context) => _AddUserDialog(isSuperAdmin: isSuperAdmin),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(userRepositoryProvider)
          .createUser(
            username: result.username,
            password: result.password!,
            role: result.role ?? UserRole.staff,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.userAdded)));
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  Future<void> _editUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    List<AppUser> users,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(sessionProvider);
    final isSuperAdmin = current?.isSuperAdmin == true;
    final activeAdmins = users.where((u) => u.isAdmin && u.isActive).length;

    final result = await showDialog<_UserResult>(
      context: context,
      builder: (context) =>
          _EditUserDialog(user: user, activeAdmins: activeAdmins, isSuperAdmin: isSuperAdmin),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final demotingLastAdmin =
        user.isAdmin &&
        result.role != null &&
        !result.role!.isAnyAdmin &&
        activeAdmins <= 1;
    final deactivatingLastAdmin =
        user.isAdmin &&
        result.isActive == false &&
        result.role != null &&
        result.role!.isAnyAdmin &&
        activeAdmins <= 1;
    if (demotingLastAdmin || deactivatingLastAdmin) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.needOneActiveAdmin)));
      return;
    }

    try {
      await ref
          .read(userRepositoryProvider)
          .updateUser(
            user.id,
            password: result.password,
            role: result.role,
            isActive: result.isActive,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.userSaved)));
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    List<AppUser> users,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(sessionProvider);
    if (current?.id == user.id) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.cannotDeactivateSelf)));
      return;
    }

    final activeAdmins = users.where((u) => u.isAdmin && u.isActive).length;
    if (user.isAdmin && user.isActive && activeAdmins <= 1) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.needOneActiveAdmin)));
      return;
    }

    try {
      await ref
          .read(userRepositoryProvider)
          .updateUser(user.id, isActive: !user.isActive);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.userSaved)));
    } on Exception {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    List<AppUser> users,
  ) async {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.localeName.startsWith('ar');
    final current = ref.read(sessionProvider);

    if (current?.id == user.id) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'لا يمكن حذف حسابك الحالي المسجل به الدخول'
                  : 'Cannot delete your own account',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      return;
    }

    final activeAdmins = users.where((u) => u.isAdmin && u.isActive).length;
    if (user.isAdmin && activeAdmins <= 1) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.needOneActiveAdmin),
            backgroundColor: Colors.red.shade800,
          ),
        );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_outlined, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'حذف المستخدم نهائياً' : 'Delete User Permanently',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من حذف المستخدم "${user.username}" نهائياً من النظام؟\n\nلا يمكن التراجع عن هذا الإجراء.'
              : 'Are you sure you want to permanently delete user "${user.username}" from the system?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isArabic ? 'نعم، حذف نهائي' : 'Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(userRepositoryProvider).deleteUser(user.id);
      ref.invalidate(userListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم حذف المستخدم "${user.username}" نهائياً من النظام بنجاح'
                  : 'User "${user.username}" was permanently deleted.',
            ),
            backgroundColor: const Color(0xFF28C76F),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red.shade800,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(sessionProvider);
    final usersAsync = ref.watch(userListProvider);
    final isSuperAdmin = current?.isSuperAdmin == true;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.group_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.users,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                if (!isSuperAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.branchStaffManagement,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _addUser(context, ref),
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: Text(isSuperAdmin ? l10n.addUser : l10n.addStaffMember),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                  data: (users) => ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelf = current?.id == user.id;
                      final canModify = isSuperAdmin || (!user.isAdmin && !isSelf);

                      String roleTitle = l10n.roleStaff;
                      Color roleColor = theme.colorScheme.surfaceContainerHighest;
                      if (user.isSuperAdmin) {
                        roleTitle = l10n.superAdminRole;
                        roleColor = Colors.purple.shade100;
                      } else if (user.isBranchAdmin) {
                        roleTitle = l10n.branchAdminRole;
                        roleColor = theme.colorScheme.primaryContainer;
                      } else if (user.isAdmin) {
                        roleTitle = l10n.roleAdmin;
                        roleColor = theme.colorScheme.primaryContainer;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.username.isEmpty
                                ? '?'
                                : user.username[0].toUpperCase(),
                          ),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Chip(
                              label: roleTitle,
                              color: roleColor,
                            ),
                            if (!user.isActive)
                              _Chip(
                                label: l10n.inactive,
                                color: theme.colorScheme.errorContainer,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          DateFormat.yMd(
                            l10n.localeName,
                          ).add_Hm().format(user.createdAt),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: canModify ? l10n.edit : l10n.managedBySuperAdmin,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: canModify
                                  ? () => _editUser(context, ref, user, users)
                                  : null,
                            ),
                            Switch(
                              value: user.isActive,
                              onChanged: (isSelf || !canModify)
                                  ? null
                                  : (_) => _toggleActive(
                                      context,
                                      ref,
                                      user,
                                      users,
                                    ),
                            ),
                            IconButton(
                              tooltip: (isSelf || !canModify)
                                  ? null
                                  : (l10n.localeName.startsWith('ar')
                                      ? 'حذف المستخدم نهائياً'
                                      : 'Delete user permanently'),
                              icon: Icon(
                                Icons.delete_outline,
                                color: (isSelf || !canModify)
                                    ? theme.colorScheme.outlineVariant
                                    : Colors.red.shade700,
                              ),
                              onPressed: (isSelf || !canModify)
                                  ? null
                                  : () => _deleteUser(
                                      context,
                                      ref,
                                      user,
                                      users,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _UserResult {
  const _UserResult({
    required this.username,
    required this.password,
    this.role,
    this.isActive,
  });

  final String username;
  final String? password;
  final UserRole? role;
  final bool? isActive;
}

class _AddUserDialog extends ConsumerStatefulWidget {
  const _AddUserDialog({required this.isSuperAdmin});

  final bool isSuperAdmin;

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.staff;
  String? _usernameError;
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    AppUser? existing;
    try {
      existing = await ref
          .read(userRepositoryProvider)
          .findByUsername(_usernameController.text.trim());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
    if (!mounted) {
      return;
    }
    if (existing != null) {
      setState(() => _usernameError = l10n.alreadyInUse(l10n.username));
      return;
    }
    Navigator.of(context).pop(
      _UserResult(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: widget.isSuperAdmin ? _role : UserRole.staff,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isSuperAdmin ? l10n.addUser : 'Add Staff Member'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return _usernameError;
                },
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.isSuperAdmin)
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.staff,
                      child: Text(l10n.roleStaff),
                    ),
                    DropdownMenuItem(
                      value: UserRole.branchAdmin,
                      child: Text(l10n.branchAdminRole),
                    ),
                    DropdownMenuItem(
                      value: UserRole.superAdmin,
                      child: Text(l10n.superAdminRole),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _role = value);
                    }
                  },
                )
              else
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  child: Text(l10n.roleStaff),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  const _EditUserDialog({
    required this.user,
    required this.activeAdmins,
    required this.isSuperAdmin,
  });

  final AppUser user;
  final int activeAdmins;
  final bool isSuperAdmin;

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late UserRole _role;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _isActive = widget.user.isActive;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final newPassword = _passwordController.text.trim();
    final roleChanged = _role != widget.user.role;
    final demoting =
        widget.user.isAdmin && roleChanged && !_role.isAnyAdmin;
    if (demoting && widget.activeAdmins <= 1) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.needOneActiveAdmin)));
      return;
    }
    Navigator.of(context).pop(
      _UserResult(
        username: widget.user.username,
        password: newPassword.isEmpty ? null : newPassword,
        role: roleChanged ? _role : null,
        isActive: _isActive == widget.user.isActive ? null : _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l10n.editUser}: ${widget.user.username}'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSuperAdmin)
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.staff,
                      child: Text(l10n.roleStaff),
                    ),
                    DropdownMenuItem(
                      value: UserRole.branchAdmin,
                      child: Text(l10n.branchAdminRole),
                    ),
                    DropdownMenuItem(
                      value: UserRole.superAdmin,
                      child: Text(l10n.superAdminRole),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _role = value);
                    }
                  },
                )
              else
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  child: Text(widget.user.isAdmin ? l10n.roleAdmin : l10n.roleStaff),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  helperText: l10n.leaveEmptyToKeep,
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_isActive ? l10n.active : l10n.inactive),
                value: _isActive,
                onChanged:
                    widget.activeAdmins <= 1 && widget.user.isAdmin && _isActive
                    ? (_) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(content: Text(l10n.needOneActiveAdmin)),
                          );
                      }
                    : (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
