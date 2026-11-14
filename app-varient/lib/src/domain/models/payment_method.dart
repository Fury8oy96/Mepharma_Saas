/// Payment methods accepted at the POS.
///
/// Stored as a plain string (`name`) in `Sales.paymentMethod`.
enum PaymentMethod { cash, card, bankTransfer, credit, mobileMoney }

/// Input from the payment dialog: how the customer paid, how much was received,
/// and optional transaction reference (required for bank transfer).
class PaymentInput {
  const PaymentInput({
    required this.method,
    required this.receivedCents,
    this.transactionReference,
  });

  final PaymentMethod method;
  final int receivedCents;
  final String? transactionReference;
}
