
enum UserType {
  participant,
  organizer,
  admin,
}

class User {
  final String id;
  final String email;
  final String name;
  final String universityId;
  final UserType type;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.universityId,
    required this.type,
    this.profileImageUrl,
    required this.createdAt,
    this.lastLoginAt,
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'universityId': universityId,
      'type': type.name,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      universityId: json['universityId'] as String,
      type: _parseUserType(json['type']),
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: _parseDateTime(json['createdAt'])!,
      lastLoginAt: _parseDateTime(json['lastLoginAt']),
    );
  }

  // Map aliases
  Map<String, dynamic> toMap() => toJson();

  factory User.fromMap(Map<String, dynamic> map) => User.fromJson(map);

  // Role helpers
  bool get isOrganizer => type == UserType.organizer;
  bool get isParticipant => type == UserType.participant;
  bool get isAdmin => type == UserType.admin;

  // Equality and diagnostics
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.universityId == universityId &&
        other.type == type &&
        other.profileImageUrl == profileImageUrl &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      email,
      name,
      universityId,
      type,
      profileImageUrl,
      createdAt,
      lastLoginAt,
    );
  }

  @override
  String toString() {
    return 'User(id: ' + id + ', email: ' + email + ', name: ' + name + ', universityId: ' + universityId + ', type: ' + type.name + ', profileImageUrl: ' + (profileImageUrl ?? 'null') + ', createdAt: ' + createdAt.toIso8601String() + ', lastLoginAt: ' + (lastLoginAt?.toIso8601String() ?? 'null') + ')';
  }


  User copyWith({
    String? id,
    String? email,
    String? name,
    String? universityId,
    UserType? type,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      universityId: universityId ?? this.universityId,
      type: type ?? this.type,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // Helpers
  static UserType _parseUserType(dynamic raw) {
    if (raw is UserType) return raw;
    if (raw is String) {
      final lower = raw.toLowerCase();
      for (final value in UserType.values) {
        if (value.name.toLowerCase() == lower) return value;
      }
      // Try legacy labels
      if (lower == 'org' || lower == 'admin' || lower == 'organiser') {
        return UserType.organizer;
      }
      return UserType.participant;
    }
    if (raw is int) {
      // Defensive: map index if within range
      if (raw >= 0 && raw < UserType.values.length) {
        return UserType.values[raw];
      }
    }
    return UserType.participant;
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    if (raw is int) {
      // Assume millisecondsSinceEpoch
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return null;
  }


}
