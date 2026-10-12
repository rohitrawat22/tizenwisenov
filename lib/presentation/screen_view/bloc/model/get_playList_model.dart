class GetplayListModel {
  String? id;
  String? deviceId;
  String? name;
  String? type;
  String? serverUrl;
  String? username;
  String? password;
  String? m3uUrl;
  bool? isPinned;
  bool? isLocked;

  GetplayListModel({
    this.id,
    this.deviceId,
    this.name,
    this.type,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uUrl,
    this.isPinned = false,
    this.isLocked = false,
  });

  GetplayListModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    deviceId = json['deviceId'];
    name = json['name'];
    type = json['type'];
    serverUrl = json['serverUrl'];
    username = json['username'];
    password = json['password'];
    m3uUrl = json['m3uUrl'];
    // In Java, we named it 'pinned' but here it's mapped to 'isPinned' with a fallback.
    // Let's also parse the new field 'isLocked' (which we returned as 'isLocked' from the backend)
    isPinned = json['pinned'] ?? json['isPinned'] ?? false;
    isLocked = json['isLocked'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['deviceId'] = deviceId;
    data['name'] = name;
    data['type'] = type;
    data['serverUrl'] = serverUrl;
    data['username'] = username;
    data['password'] = password;
    data['m3uUrl'] = m3uUrl;
    data['isPinned'] = isPinned;
    data['isLocked'] = isLocked;
    return data;
  }
}
