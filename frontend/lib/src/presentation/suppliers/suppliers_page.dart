import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/app_supplier.dart';
import '../../l10n/generated/app_localizations.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  Future<void> _openForm(BuildContext context, {AppSupplier? supplier}) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final contactController =
        TextEditingController(text: supplier?.contactPerson ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final addressController = TextEditingController(text: supplier?.address ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(supplier == null ? l10n.addSupplier : l10n.editSupplier),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.supplierName),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? l10n.fieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: contactController,
                      decoration: InputDecoration(labelText: l10n.supplierCompany),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: l10n.supplierCompanyContact),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(labelText: l10n.address),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      setDialogState(() => saving = true);
                      final repo = ProviderScope.containerOf(
                        dialogContext,
                        listen: false,
                      ).read(supplierRepositoryProvider);
                      final name = nameController.text.trim();
                      try {
                        if (supplier == null) {
                          await repo.create(
                            name: name,
                            contactPerson: _emptyToNull(contactController.text),
                            phone: _emptyToNull(phoneController.text),
                            email: _emptyToNull(emailController.text),
                            address: _emptyToNull(addressController.text),
                          );
                        } else {
                          await repo.update(
                            supplier.id,
                            name: name,
                            contactPerson: _emptyToNull(contactController.text),
                            phone: _emptyToNull(phoneController.text),
                            email: _emptyToNull(emailController.text),
                            address: _emptyToNull(addressController.text),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception {
                        setDialogState(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(supplier == null ? l10n.supplierAdded : l10n.supplierSaved)),
        );
    }
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _confirmDelete(BuildContext context, AppSupplier supplier) async {
    final l10n = AppLocalizations.of(context);
    final repo = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(supplierRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteSupplier(supplier.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.delete(supplier.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(supplierListProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.read(supplierRepositoryProvider).refresh();
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing suppliers...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addSupplier),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: suppliersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                  data: (suppliers) => suppliers.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noSuppliers,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: suppliers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final supplier = suppliers[index];
                            return ListTile(
                              title: Text(
                                supplier.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if ((supplier.contactPerson?.isNotEmpty ?? false))
                                    supplier.contactPerson!,
                                  if ((supplier.phone?.isNotEmpty ?? false))
                                    supplier.phone!,
                                  if ((supplier.email?.isNotEmpty ?? false))
                                    supplier.email!,
                                ].join(' · '),
                              ),
                              isThreeLine: false,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: l10n.edit,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _openForm(context, supplier: supplier),
                                  ),
                                  IconButton(
                                    tooltip: l10n.delete,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _confirmDelete(context, supplier),
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
