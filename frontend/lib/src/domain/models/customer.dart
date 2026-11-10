/// A customer tracked on the account, with a running credit balance.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.creditLimit = 0,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  /// Credit limit in minor units (cents); 0 means no explicit limit.
  final int creditLimit;
  final DateTime createdAt;
}

/// A customer together with their current outstanding balance and the total
/// paid against it.
class CustomerWithBalance {
  const CustomerWithBalance({
    required this.customer,
    required this.outstanding,
    required this.totalPaid,
    required this.totalCredit,
  });

  final Customer customer;

  /// Minor units (cents): credit sales minus payments.
  final int outstanding;

  /// Minor units (cents) paid on account.
  final int totalPaid;

  /// Minor units (cents) charged on account.
  final int totalCredit;

  bool get hasBalance => outstanding > 0;

  /// Whether the outstanding balance exceeds the customer's credit limit.
  /// A limit of 0 means no limit was set.
  bool get isOverLimit => customer.creditLimit > 0 && outstanding > customer.creditLimit;
}

/// A payment received towards a customer's account balance.
class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.customerId,
    this.userId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  final int id;
  final int customerId;
  final int? userId;

  /// Minor units (cents).
  final int amount;
  final String? note;
  final DateTime createdAt;
}
