import 'package:cloud_firestore/cloud_firestore.dart';

class CredentialModel {
  final String credId;
  final String userId;
  final String platform;
  final String username;
  final String password;
  final String url;
  final DateTime createdAt;
  final DateTime updatedAt;

  CredentialModel({
    required this.credId,
    required this.userId,
    required this.platform,
    required this.username,
    required this.password,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CredentialModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CredentialModel(
      credId: data['credId'] ?? '',
      userId: data['userId'] ?? '',
      platform: data['platform'] ?? '',
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'credId': credId,
      'userId': userId,
      'platform': platform,
      'username': username,
      'password': password,
      'url': url,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CredentialModel copyWith({
    String? credId,
    String? userId,
    String? platform,
    String? username,
    String? password,
    String? url,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CredentialModel(
      credId: credId ?? this.credId,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
