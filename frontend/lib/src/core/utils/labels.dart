import '../../data/db/enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// Localized label for a stored payment method name ('cash'/'card'/'bankTransfer'/'mobileMoney'/'credit').
String paymentMethodLabel(String? method, AppLocalizations l10n) {
  switch (method) {
    case 'cash':
      return l10n.paymentCash;
    case 'card':
      return l10n.paymentCard;
    case 'bankTransfer':
      return l10n.paymentBankTransfer;
    case 'mobileMoney':
      return l10n.paymentMobileMoney;
    case 'credit':
      return l10n.paymentCredit;
    default:
      return method ?? '';
  }
}

/// Localized label for a sale status.
String saleStatusLabel(SaleStatus status, AppLocalizations l10n) {
  switch (status) {
    case SaleStatus.completed:
      return l10n.saleStatusCompleted;
    case SaleStatus.returned:
      return l10n.saleStatusReturned;
    case SaleStatus.voided:
      return l10n.saleStatusVoided;
  }
}
