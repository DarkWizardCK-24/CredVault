import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's profile (never contains anything secret).
class UserModel {
  /// Firebase Authentication uid.
  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;

  /// The id earlier versions used (e.g. `USER000012`). Only kept so
  /// credentials saved by those versions can be migrated.
  final String? legacyUserId;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.legacyUserId,
  });

  UserModel copyWith({String? name}) => UserModel(
    uid: uid,
    name: name ?? this.name,
    email: email,
    createdAt: createdAt,
    legacyUserId: legacyUserId,
  );

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final legacy = data['userId'] as String?;
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      legacyUserId: (legacy != null && legacy != doc.id) ? legacy : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
