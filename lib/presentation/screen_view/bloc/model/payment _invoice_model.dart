class PaymentInvoiceModel {
  String? invoiceNumber;
  String? paymentId;
  String? deviceId;
  String? transactionDate;
  String? status;
  String? plan;
  String? planDisplayName;
  double? amount;
  String? currency;
  String? paymentMethod;
  String? paypalOrderId;
  String? paypalCaptureId;
  String? createdAt;
  String? updatedAt;
  /// Subscription expiry date returned by the server (ISO-8601 string).
  String? expiresAt;

  PaymentInvoiceModel({
    this.invoiceNumber,
    this.paymentId,
    this.deviceId,
    this.transactionDate,
    this.status,
    this.plan,
    this.planDisplayName,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.paypalOrderId,
    this.paypalCaptureId,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });
  factory PaymentInvoiceModel.empty() {
    return PaymentInvoiceModel();
  }

  PaymentInvoiceModel.fromJson(Map<String, dynamic> json) {
    invoiceNumber = json['invoiceNumber'];
    paymentId = json['paymentId'];
    deviceId = json['deviceId'];
    transactionDate = json['transactionDate'];
    status = json['status'];
    plan = json['plan'];
    planDisplayName = json['planDisplayName'];
    amount = json['amount'];
    currency = json['currency'];
    paymentMethod = json['paymentMethod'];
    paypalOrderId = json['paypalOrderId'];
    paypalCaptureId = json['paypalCaptureId'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    expiresAt = json['expiresAt'] ?? json['expiredAt'] ?? json['expiry'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['invoiceNumber'] = invoiceNumber;
    data['paymentId'] = paymentId;
    data['deviceId'] = deviceId;
    data['transactionDate'] = transactionDate;
    data['status'] = status;
    data['plan'] = plan;
    data['planDisplayName'] = planDisplayName;
    data['amount'] = amount;
    data['currency'] = currency;
    data['paymentMethod'] = paymentMethod;
    data['paypalOrderId'] = paypalOrderId;
    data['paypalCaptureId'] = paypalCaptureId;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['expiresAt'] = expiresAt;
    return data;
  }
}
