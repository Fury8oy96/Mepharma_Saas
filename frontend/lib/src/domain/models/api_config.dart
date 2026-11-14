enum DatabaseMode {
  local,
  onlineApi,
}

class ApiConfig {
  const ApiConfig({
    required this.mode,
    required this.baseUrl,
    this.token,
    required this.branchId,
    this.pharmacyDomain = 'main.localhost:8000',
    this.pharmacyCode = 'main',
    this.licenseKey,
    this.isConfigured = false,
    this.isLicenseValid = false,
    this.pharmacyName,
    this.pharmacyPhone,
    this.pharmacyAddress,
    this.currency,
    this.currencySymbol,
    this.taxRate,
    this.receiptFooter,
    this.licenseExpiresAt,
    this.licensePlan,
    this.validityDaysRemaining,
    this.terminalHardwareId,
    this.terminalName,
    this.seatNumber,
  });

  final DatabaseMode mode;
  final String baseUrl;
  final String? token;
  final int branchId;
  final String pharmacyDomain;
  final String pharmacyCode;
  final String? licenseKey;
  final bool isConfigured;
  final bool isLicenseValid;
  final String? pharmacyName;
  final String? pharmacyPhone;
  final String? pharmacyAddress;
  final String? currency;
  final String? currencySymbol;
  final double? taxRate;
  final String? receiptFooter;
  final String? licenseExpiresAt;
  final String? licensePlan;
  final int? validityDaysRemaining;
  final String? terminalHardwareId;
  final String? terminalName;
  final int? seatNumber;

  ApiConfig copyWith({
    DatabaseMode? mode,
    String? baseUrl,
    String? token,
    int? branchId,
    String? pharmacyDomain,
    String? pharmacyCode,
    String? licenseKey,
    bool? isConfigured,
    bool? isLicenseValid,
    String? pharmacyName,
    String? pharmacyPhone,
    String? pharmacyAddress,
    String? currency,
    String? currencySymbol,
    double? taxRate,
    String? receiptFooter,
    String? licenseExpiresAt,
    String? licensePlan,
    int? validityDaysRemaining,
    String? terminalHardwareId,
    String? terminalName,
    int? seatNumber,
  }) {
    return ApiConfig(
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      branchId: branchId ?? this.branchId,
      pharmacyDomain: pharmacyDomain ?? this.pharmacyDomain,
      pharmacyCode: pharmacyCode ?? this.pharmacyCode,
      licenseKey: licenseKey ?? this.licenseKey,
      isConfigured: isConfigured ?? this.isConfigured,
      isLicenseValid: isLicenseValid ?? this.isLicenseValid,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyPhone: pharmacyPhone ?? this.pharmacyPhone,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      licenseExpiresAt: licenseExpiresAt ?? this.licenseExpiresAt,
      licensePlan: licensePlan ?? this.licensePlan,
      validityDaysRemaining: validityDaysRemaining ?? this.validityDaysRemaining,
      terminalHardwareId: terminalHardwareId ?? this.terminalHardwareId,
      terminalName: terminalName ?? this.terminalName,
      seatNumber: seatNumber ?? this.seatNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'baseUrl': baseUrl,
      'token': token,
      'branchId': branchId,
      'pharmacyDomain': pharmacyDomain,
      'pharmacyCode': pharmacyCode,
      'licenseKey': licenseKey,
      'isConfigured': isConfigured,
      'isLicenseValid': isLicenseValid,
      'pharmacyName': pharmacyName,
      'pharmacyPhone': pharmacyPhone,
      'pharmacyAddress': pharmacyAddress,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'taxRate': taxRate,
      'receiptFooter': receiptFooter,
      'licenseExpiresAt': licenseExpiresAt,
      'licensePlan': licensePlan,
      'validityDaysRemaining': validityDaysRemaining,
      'terminalHardwareId': terminalHardwareId,
      'terminalName': terminalName,
      'seatNumber': seatNumber,
    };
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    final mode = DatabaseMode.values.firstWhere(
      (e) => e.name == json['mode'],
      orElse: () => DatabaseMode.local,
    );
    final hasLicense =
        json['licenseKey'] != null && (json['licenseKey'] as String).isNotEmpty;
    return ApiConfig(
      mode: mode,
      baseUrl: json['baseUrl'] as String? ?? 'http://localhost:8000/api',
      token: json['token'] as String?,
      branchId: json['branchId'] as int? ?? 1,
      pharmacyDomain: json['pharmacyDomain'] as String? ??
          (json['baseUrl'] as String? ?? 'main.localhost:8000'),
      pharmacyCode: json['pharmacyCode'] as String? ?? 'main',
      licenseKey: json['licenseKey'] as String?,
      isConfigured:
          json['isConfigured'] as bool? ?? (mode == DatabaseMode.local || hasLicense),
      isLicenseValid:
          json['isLicenseValid'] as bool? ?? (mode == DatabaseMode.local),
      pharmacyName: json['pharmacyName'] as String?,
      pharmacyPhone: json['pharmacyPhone'] as String?,
      pharmacyAddress: json['pharmacyAddress'] as String?,
      currency: json['currency'] as String?,
      currencySymbol: json['currencySymbol'] as String?,
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      receiptFooter: json['receiptFooter'] as String?,
      licenseExpiresAt: json['licenseExpiresAt'] as String?,
      licensePlan: json['licensePlan'] as String?,
      validityDaysRemaining: json['validityDaysRemaining'] as int?,
      terminalHardwareId: json['terminalHardwareId'] as String?,
      terminalName: json['terminalName'] as String?,
      seatNumber: json['seatNumber'] as int?,
    );
  }
}
