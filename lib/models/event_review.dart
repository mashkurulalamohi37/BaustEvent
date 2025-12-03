import 'package:cloud_firestore/cloud_firestore.dart';

class EventReview {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final String? userEmail;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;

  EventReview({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EventReview.fromFirestore(String id, Map<String, dynamic> data) {
    return EventReview(
      id: id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] as String?,
      rating: data['rating'] ?? 5,
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  EventReview copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? userName,
    String? userEmail,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return EventReview(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

