class SubscriptionStatusModel {
  final String subscriptionId;
  final String deviceId;
  final String planName;
  final String status;
  final String type;
  final String startDate;
  final String endDate;

  SubscriptionStatusModel({
    required this.subscriptionId,
    required this.deviceId,
    required this.planName,
    required this.status,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusModel(
      subscriptionId: json['subscriptionId'] ?? '',
      deviceId: json['deviceId'] ?? '',
      planName: json['planName'] ?? '',
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionId': subscriptionId,
      'deviceId': deviceId,
      'planName': planName,
      'status': status,
      'type': type,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
