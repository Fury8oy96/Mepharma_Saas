import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/models/api_config.dart';
import '../../domain/models/customer.dart';
import '../../l10n/generated/app_localizations.dart';
import '../session/session_controller.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Customer? customer}) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final creditLimitController = TextEditingController(
      text: customer == null
          ? ''
          : formatCents(customer.creditLimit, withSeparator: true),
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final savedMessage = customer == null
        ? l10n.customerAdded
        : l10n.customerSaved;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(customer == null ? l10n.addCustomer : l10n.editCustomer),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.customerName),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.fieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(labelText: l10n.phone),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: l10n.email),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(labelText: l10n.address),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: creditLimitController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.creditLimit,
                        hintText: '0',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        return parseCents(value) < 0
                            ? l10n.creditLimitNegative
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(labelText: l10n.notes),
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
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final email = emailController.text.trim();
                      final address = addressController.text.trim();
                      final notes = notesController.text.trim();
                      final creditLimit = parseCents(
                        creditLimitController.text,
                      );
                      try {
                        final repo = ProviderScope.containerOf(
                          dialogContext,
                          listen: false,
                        ).read(customerRepositoryProvider);
                        if (await repo.isNameTaken(
                          name,
                          excludeId: customer?.id,
                        )) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(l10n.customerNameTaken)),
                            );
                          }
                          return;
                        }
                        if (customer == null) {
                          await repo.create(
                            name: name,
                            phone: phone.isEmpty ? null : phone,
                            email: email.isEmpty ? null : email,
                            address: address.isEmpty ? null : address,
                            notes: notes.isEmpty ? null : notes,
                            creditLimit: creditLimit < 0 ? 0 : creditLimit,
                          );
                        } else {
                          await repo.update(
                            customer.id,
                            name: name,
                            phone: phone.isEmpty ? null : phone,
                            email: email.isEmpty ? null : email,
                            address: address.isEmpty ? null : address,
                            notes: notes.isEmpty ? null : notes,
                            creditLimit: creditLimit < 0 ? 0 : creditLimit,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception catch (e) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(l10n.errorOccurred)),
                          );
                        }
                        debugPrint('Failed to save customer: $e');
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

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(savedMessage)));
    }
  }

  Future<void> _recordPayment(CustomerWithBalance entry, String symbol) async {
    final l10n = AppLocalizations.of(context);
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final recorded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(l10n.recordPaymentFor(entry.customer.name)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.amount,
                      prefixText: '$symbol ',
                    ),
                    validator: (value) {
                      final cents = parseCents(value ?? '');
                      return cents <= 0 ? l10n.fieldRequired : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(labelText: l10n.note),
                  ),
                ],
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
                        ).read(customerRepositoryProvider);
                        final amount = parseCents(amountController.text);
                        final note = noteController.text.trim();
                        try {
                          await repo.recordPayment(
                            customerId: entry.customer.id,
                            amount: amount,
                            note: note.isEmpty ? null : note,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on Exception catch (e) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(l10n.errorOccurred)),
                            );
                          }
                          debugPrint('Failed to record payment: $e');
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );

    if (recorded == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.paymentRecorded)));
    }
  }

  Future<void> _openDetail(CustomerWithBalance entry, String symbol) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.customer.name),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.balance, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatMoney(entry.outstanding, symbol: symbol),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: entry.hasBalance
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (entry.customer.creditLimit > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(l10n.creditLimit),
                      const Spacer(),
                      Text(
                        formatMoney(entry.customer.creditLimit, symbol: symbol),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Text(l10n.paymentHistory, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: Consumer(
                  builder: (context, ref, _) {
                    final payments = ref.watch(
                      customerPaymentsProvider(entry.customer.id),
                    );
                    return payments.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                      data: (list) => list.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noPayments,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final payment = list[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.payments_outlined),
                                  title: Text(
                                    formatMoney(payment.amount, symbol: symbol),
                                  ),
                                  subtitle: Text(
                                    _formatDate(payment.createdAt, l10n),
                                  ),
                                  trailing: payment.note == null
                                      ? null
                                      : Text(
                                          payment.note!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CustomerWithBalance entry, String symbol) async {
    final l10n = AppLocalizations.of(context);
    final repo = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(customerRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteCustomer(entry.customer.name)),
        content: Text(
          entry.hasBalance
              ? '${l10n.deleteCustomerHint}\n\n'
                    '${l10n.customerHasOutstandingBalance(formatMoney(entry.outstanding, symbol: symbol))}'
              : l10n.deleteCustomerHint,
        ),
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
      await repo.delete(entry.customer.id);
    }
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(day).inDays;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    if (dayDiff == 0) {
      return '${l10n.todayLabel} $time';
    }
    if (dayDiff == 1) {
      return '${l10n.yesterdayLabel} $time';
    }
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} $time';
  }

  Future<void> _openProductRequestDialog() async {
    final l10n = AppLocalizations.of(context);
    final customerNameController = TextEditingController();
    final phoneController = TextEditingController();
    final productNameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.bookmark_add_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              Text(l10n.outOfStockRequest),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: productNameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '${l10n.requestedDrugName} *',
                      hintText: 'e.g. Lipitor 20mg / Nexium 40mg',
                      prefixIcon: const Icon(Icons.medication_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerNameController,
                    decoration: InputDecoration(
                      labelText: '${l10n.customer} *',
                      hintText: 'e.g. John Doe',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.phone,
                      hintText: '+1 234 567 8900',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.quantity,
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: l10n.notes,
                      hintText: 'e.g. Needed soon',
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      final prodName = productNameController.text.trim();
                      final custName = customerNameController.text.trim();
                      if (prodName.isEmpty || custName.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(l10n.fieldRequired),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final config = ref.read(apiConfigProvider);
                        final qty = int.tryParse(quantityController.text.trim()) ?? 1;
                        final safeQty = qty > 0 ? qty : 1;
                        final phone = phoneController.text.trim();
                        final notes = notesController.text.trim();

                        if (config.mode == DatabaseMode.local) {
                          final user = ref.read(sessionProvider);
                          final noteParts = <String>[
                            'Customer: $custName',
                            if (phone.isNotEmpty) 'Phone: $phone',
                            if (notes.isNotEmpty) notes,
                          ];
                          await ref.read(staffFeedbackRepositoryProvider).submitFeedback(
                                productName: prodName,
                                currentStock: 0,
                                staffUserId: user?.id,
                                staffUsername: user?.username ?? 'Staff',
                                branchId: user?.branchId ?? 1,
                                urgency: 'high_demand',
                                suggestedQuantity: safeQty,
                                notes: noteParts.join(' | '),
                              );
                        } else {
                          final apiClient = ref.read(apiClientProvider);
                          await apiClient.post(
                            '/customer-requests',
                            body: {
                              'customer_name': custName,
                              'customer_phone': phone,
                              'product_name': prodName,
                              'quantity': safeQty,
                              'notes': notes,
                            },
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.customerWishlistSaved),
                              backgroundColor: Colors.teal.shade800,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('${l10n.errorOccurred}: $e')),
                          );
                        }
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customerListProvider);
    final settingsAsync = ref.watch(storeSettingsProvider);
    final symbol = settingsAsync.valueOrNull?.currencySymbol ?? '';

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchCustomers,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refresh,
                  onPressed: () {
                    ref.read(customerRepositoryProvider).refresh();
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(l10n.refreshing),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openProductRequestDialog,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.requestOutOfStockDrug),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addCustomer),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: customersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(child: Text(l10n.errorOccurred)),
                  data: (entries) {
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? entries
                        : entries
                              .where(
                                (e) =>
                                    e.customer.name.toLowerCase().contains(
                                      query,
                                    ) ||
                                    (e.customer.phone?.toLowerCase().contains(
                                          query,
                                        ) ??
                                        false),
                              )
                              .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noCustomers,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final customer = entry.customer;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              customer.name.isEmpty
                                  ? '?'
                                  : customer.name[0].toUpperCase(),
                            ),
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              customer.phone,
                              if (entry.hasBalance)
                                '${l10n.balance}: '
                                    '${formatMoney(entry.outstanding, symbol: symbol)}',
                              if (entry.isOverLimit) l10n.overLimit,
                            ].where((s) => s != null && s.isNotEmpty).join(' • '),
                          ),
                          isThreeLine: entry.isOverLimit,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.payments,
                                icon: const Icon(Icons.payments_outlined),
                                onPressed: () => _openDetail(entry, symbol),
                              ),
                              IconButton(
                                tooltip: l10n.recordPayment,
                                icon: const Icon(Icons.add_card),
                                onPressed: () => _recordPayment(entry, symbol),
                              ),
                              IconButton(
                                tooltip: l10n.edit,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(customer: customer),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(entry, symbol),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
