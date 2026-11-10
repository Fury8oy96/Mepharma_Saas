/// Payment methods accepted at the POS.
///
/// Stored as a plain string (`name`) in `Sales.paymentMethod`.
enum PaymentMethod { cash, card, mobileMoney, credit }

/// Input from the payment dialog: how the customer paid and, for cash, how
/// much they handed over (minor units).
class PaymentInput {
  const PaymentInput({required this.method, required this.receivedCents});

  final PaymentMethod method;
  final int receivedCents;
}
