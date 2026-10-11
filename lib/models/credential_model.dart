import 'dart:convert';

import 'package:cred_vault/models/credential_category.dart';

/// A saved login, as the user sees it (decrypted, in memory only).
///
/// On the server only an encrypted blob of these fields is stored, see
/// [toPayload] and [Credential.fromPayload].
class Credential {
  final String id;

  /// Name of the service picked from the list (e.g. `GitHub`).
  final String platform;

  /// Optional custom name; mainly for the `Other` platform.
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final CredentialCategory category;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the password was last changed (drives the "old password" warning).
  final DateTime passwordChangedAt;

  const Credential({
    required this.id,
    required this.platform,
    this.title = '',
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.category = CredentialCategory.other,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    required this.passwordChangedAt,
  });

  /// What to show as the item's name.
  String get displayName => title.trim().isNotEmpty ? title.trim() : platform;

  Credential copyWith({
    String? id,
    String? platform,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    CredentialCategory? category,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? passwordChangedAt,
  }) => Credential(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    title: title ?? this.title,
    username: username ?? this.username,
    password: password ?? this.password,
    url: url ?? this.url,
    notes: notes ?? this.notes,
    category: category ?? this.category,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
  );

  /// The JSON that gets encrypted before it is stored.
  String toPayload() => jsonEncode({
    'platform': platform,
    'title': title,
    'username': username,
    'password': password,
    'url': url,
    'notes': notes,
    'category': category.name,
    'favorite': favorite,
    'passwordChangedAt': passwordChangedAt.toIso8601String(),
  });

  factory Credential.fromPayload(
    String id,
    String json, {
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return Credential(
      id: id,
      platform: map['platform'] as String? ?? 'Other',
      title: map['title'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      url: map['url'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      category: CredentialCategory.fromName(map['category'] as String?),
      favorite: map['favorite'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      passwordChangedAt:
          DateTime.tryParse(map['passwordChangedAt'] as String? ?? '') ??
          updatedAt,
    );
  }
}
