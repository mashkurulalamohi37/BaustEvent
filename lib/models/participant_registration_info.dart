
enum PaymentMethod {
  bkash,
  handCash,
}

enum PaymentStatus {
  pending,
  approved,
  rejected,
  completed,
}

class ParticipantRegistrationInfo {
  final String eventId;
  final String userId;
  final String? level;
  final String? term;
  final String? batch;
  final String? section;
  final String? tshirtSize;
  final String? foodPreference;
  final String? hall;
  final String? gender;
  final String? personalNumber;
  final String? guardianNumber;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime registeredAt;

  const ParticipantRegistrationInfo({
    required this.eventId,
    required this.userId,
    this.level,
    this.term,
    this.batch,
    this.section,
    this.tshirtSize,
    this.foodPreference,
    this.hall,
    this.gender,
    this.personalNumber,
    this.guardianNumber,
    this.paymentMethod,
    this.paymentStatus,
    required this.registeredAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'level': level,
      'term': term,
      'batch': batch,
      'section': section,
      'tshirtSize': tshirtSize,
      'foodPreference': foodPreference,
      'hall': hall,
      'gender': gender,
      'personalNumber': personalNumber,
      'guardianNumber': guardianNumber,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  static ParticipantRegistrationInfo fromFirestore(Map<String, dynamic> data) {
    return ParticipantRegistrationInfo(
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      level: data['level'] as String?,
      term: data['term'] as String?,
      batch: data['batch'] as String?,
      section: data['section'] as String?,
      tshirtSize: data['tshirtSize'] as String?,
      foodPreference: data['foodPreference'] as String?,
      hall: data['hall'] as String?,
      gender: data['gender'] as String?,
      personalNumber: data['personalNumber'] as String?,
      guardianNumber: data['guardianNumber'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
      registeredAt: data['registeredAt'] != null
          ? DateTime.tryParse(data['registeredAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

