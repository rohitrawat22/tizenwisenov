class DeviceKeyModel {
  String? activationKey;
  int? expiresInSeconds;
  String? expiresAt;

  DeviceKeyModel({this.activationKey, this.expiresInSeconds, this.expiresAt});

  DeviceKeyModel.fromJson(Map<String, dynamic> json) {
    activationKey = json['activationKey'];
    expiresInSeconds = json['expiresInSeconds'];
    expiresAt = json['expiresAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['activationKey'] = activationKey;
    data['expiresInSeconds'] = expiresInSeconds;
    data['expiresAt'] = expiresAt;
    return data;
  }
}
