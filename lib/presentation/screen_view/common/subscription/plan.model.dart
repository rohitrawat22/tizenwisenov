class AvailablePlanModel {
  String? id;
  String? name;
  int? durationDays;
  double? price;
  String? currency;
  String? description;
  bool? active;
  DateTime? createdAt;

  AvailablePlanModel({
    this.id,
    this.name,
    this.durationDays,
    this.price,
    this.currency,
    this.description,
    this.active,
    this.createdAt,
  });

  factory AvailablePlanModel.fromJson(Map<String, dynamic> json) {
    return AvailablePlanModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      durationDays: json['durationDays'] as int?,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      description: json['description'] as String?,
      active: json['active'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationDays': durationDays,
      'price': price,
      'currency': currency,
      'description': description,
      'active': active,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
