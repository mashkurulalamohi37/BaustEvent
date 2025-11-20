
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String category;
  final String organizerId;
  final List<String> participants;
  final EventStatus status;
  final int maxParticipants;
  final String? imageUrl;
  final DateTime? registrationCloseDate;
  final bool paymentRequired;
  final double? paymentAmount;
  final String? bkashNumber;
  final String? nagadNumber;
  final bool requireLevel;
  final bool requireTerm;
  final bool requireBatch;
  final bool requireSection;
  final bool requireTshirtSize;
  final bool requireFood;
  final bool requireHandCash;
  final bool requireHall;
  final bool requireGender;
  final bool requirePersonalNumber;
  final bool requireGuardianNumber;
  final DateTime createdAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.category,
    required this.organizerId,
    this.participants = const [],
    this.status = EventStatus.draft,
    this.maxParticipants = 100,
    this.imageUrl,
    this.registrationCloseDate,
    this.paymentRequired = false,
    this.paymentAmount,
    this.bkashNumber,
    this.nagadNumber,
    this.requireLevel = false,
    this.requireTerm = false,
    this.requireBatch = false,
    this.requireSection = false,
    this.requireTshirtSize = false,
    this.requireFood = false,
    this.requireHandCash = false,
    this.requireHall = false,
    this.requireGender = false,
    this.requirePersonalNumber = false,
    this.requireGuardianNumber = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime(2020, 1, 1);

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'category': category,
      'organizerId': organizerId,
      'participants': participants,
      'status': status.name,
      'maxParticipants': maxParticipants,
      'imageUrl': imageUrl,
      'registrationCloseDate': registrationCloseDate?.toIso8601String(),
      'paymentRequired': paymentRequired,
      'paymentAmount': paymentAmount,
      'bkashNumber': bkashNumber,
      'nagadNumber': nagadNumber,
      'requireLevel': requireLevel,
      'requireTerm': requireTerm,
      'requireBatch': requireBatch,
      'requireSection': requireSection,
      'requireTshirtSize': requireTshirtSize,
      'requireFood': requireFood,
      'requireHandCash': requireHandCash,
      'requireHall': requireHall,
      'requireGender': requireGender,
      'requirePersonalNumber': requirePersonalNumber,
      'requireGuardianNumber': requireGuardianNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      location: json['location'],
      category: json['category'],
      organizerId: json['organizerId'],
      participants: List<String>.from(json['participants'] ?? []),
      status: EventStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EventStatus.draft,
      ),
      maxParticipants: json['maxParticipants'] ?? 100,
      imageUrl: json['imageUrl'],
      registrationCloseDate: json['registrationCloseDate'] != null
          ? DateTime.tryParse(json['registrationCloseDate'])
          : null,
      paymentRequired: json['paymentRequired'] ?? false,
      paymentAmount: json['paymentAmount'] != null 
          ? (json['paymentAmount'] is int 
              ? (json['paymentAmount'] as int).toDouble() 
              : json['paymentAmount'] as double?)
          : null,
      bkashNumber: json['bkashNumber'] as String?,
      nagadNumber: json['nagadNumber'] as String?,
      requireLevel: json['requireLevel'] ?? false,
      requireTerm: json['requireTerm'] ?? false,
      requireBatch: json['requireBatch'] ?? false,
      requireSection: json['requireSection'] ?? false,
      requireTshirtSize: json['requireTshirtSize'] ?? false,
      requireFood: json['requireFood'] ?? false,
      requireHandCash: json['requireHandCash'] ?? false,
      requireHall: json['requireHall'] ?? false,
      requireGender: json['requireGender'] ?? false,
      requirePersonalNumber: json['requirePersonalNumber'] ?? false,
      requireGuardianNumber: json['requireGuardianNumber'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }


  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    String? category,
    String? organizerId,
    List<String>? participants,
    EventStatus? status,
    int? maxParticipants,
    String? imageUrl,
    DateTime? registrationCloseDate,
    bool registrationCloseDateSet = false,
    bool? paymentRequired,
    double? paymentAmount,
    String? bkashNumber,
    String? nagadNumber,
    bool? requireLevel,
    bool? requireTerm,
    bool? requireBatch,
    bool? requireSection,
    bool? requireTshirtSize,
    bool? requireFood,
    bool? requireHandCash,
    bool? requireHall,
    bool? requireGender,
    bool? requirePersonalNumber,
    bool? requireGuardianNumber,
    DateTime? createdAt,
    bool createdAtSet = false,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      category: category ?? this.category,
      organizerId: organizerId ?? this.organizerId,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      imageUrl: imageUrl ?? this.imageUrl,
      registrationCloseDate: registrationCloseDateSet
          ? registrationCloseDate
          : this.registrationCloseDate,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      bkashNumber: bkashNumber ?? this.bkashNumber,
      nagadNumber: nagadNumber ?? this.nagadNumber,
      requireLevel: requireLevel ?? this.requireLevel,
      requireTerm: requireTerm ?? this.requireTerm,
      requireBatch: requireBatch ?? this.requireBatch,
      requireSection: requireSection ?? this.requireSection,
      requireTshirtSize: requireTshirtSize ?? this.requireTshirtSize,
      requireFood: requireFood ?? this.requireFood,
      requireHandCash: requireHandCash ?? this.requireHandCash,
      requireHall: requireHall ?? this.requireHall,
      requireGender: requireGender ?? this.requireGender,
      requirePersonalNumber: requirePersonalNumber ?? this.requirePersonalNumber,
      requireGuardianNumber: requireGuardianNumber ?? this.requireGuardianNumber,
      createdAt: createdAtSet ? createdAt : (createdAt ?? this.createdAt),
    );
  }

  bool get isRegistrationClosed {
    if (registrationCloseDate == null) return false;
    final now = DateTime.now();
    final cutoff = registrationCloseDate!.isUtc
        ? registrationCloseDate!.toLocal()
        : registrationCloseDate!;
    return now.isAfter(cutoff);
  }

  bool get isEventDatePassed {
    final now = DateTime.now();
    final eventDate = date.isUtc ? date.toLocal() : date;
    // Compare only the date part (ignore time)
    final nowDate = DateTime(now.year, now.month, now.day);
    final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return nowDate.isAfter(eventDateOnly);
  }

}

// Firestore helpers
extension EventFirestore on Event {
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      // Store as Timestamp-compatible ISO string for simplicity; services will convert when needed
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'category': category,
      'organizerId': organizerId,
      'participants': participants,
      'status': status.name,
      'maxParticipants': maxParticipants,
      'imageUrl': imageUrl,
      'registrationCloseDate': registrationCloseDate?.toIso8601String(),
      'paymentRequired': paymentRequired,
      'paymentAmount': paymentAmount,
      'bkashNumber': bkashNumber,
      'nagadNumber': nagadNumber,
      'requireLevel': requireLevel,
      'requireTerm': requireTerm,
      'requireBatch': requireBatch,
      'requireSection': requireSection,
      'requireTshirtSize': requireTshirtSize,
      'requireFood': requireFood,
      'requireHandCash': requireHandCash,
      'requireHall': requireHall,
      'requireGender': requireGender,
      'requirePersonalNumber': requirePersonalNumber,
      'requireGuardianNumber': requireGuardianNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Event fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String id = doc.id as String;
    // Accept either Timestamp-like map, millis, or ISO string
    DateTime _parseDate(dynamic raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        return parsed ?? DateTime.now();
      }
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      // Firestore Timestamp has toDate()
      try {
        final toDate = raw.toDate();
        if (toDate is DateTime) return toDate;
      } catch (_) {}
      return DateTime.now();
    }

    return Event(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: _parseDate(data['date']),
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      category: data['category'] ?? '',
      organizerId: data['organizerId'] ?? '',
      participants: List<String>.from(data['participants'] ?? const []),
      status: EventStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'draft'),
        orElse: () => EventStatus.draft,
      ),
      maxParticipants: (data['maxParticipants'] as int?) ?? 100,
      imageUrl: data['imageUrl'] as String?,
      registrationCloseDate: data['registrationCloseDate'] != null
          ? _parseDate(data['registrationCloseDate'])
          : null,
      paymentRequired: data['paymentRequired'] ?? false,
      paymentAmount: data['paymentAmount'] != null 
          ? (data['paymentAmount'] is int 
              ? (data['paymentAmount'] as int).toDouble() 
              : data['paymentAmount'] as double?)
          : null,
      bkashNumber: data['bkashNumber'] as String?,
      nagadNumber: data['nagadNumber'] as String?,
      requireLevel: data['requireLevel'] ?? false,
      requireTerm: data['requireTerm'] ?? false,
      requireBatch: data['requireBatch'] ?? false,
      requireSection: data['requireSection'] ?? false,
      requireTshirtSize: data['requireTshirtSize'] ?? false,
      requireFood: data['requireFood'] ?? false,
      requireHandCash: data['requireHandCash'] ?? false,
      requireHall: data['requireHall'] ?? false,
      requireGender: data['requireGender'] ?? false,
      requirePersonalNumber: data['requirePersonalNumber'] ?? false,
      requireGuardianNumber: data['requireGuardianNumber'] ?? false,
      createdAt: data['createdAt'] != null
          ? _parseDate(data['createdAt'])
          : _parseDate(data['date']), // Use event date as fallback for old events without createdAt
    );
  }
}

enum EventStatus {
  draft,
  published,
  active,
  completed,
  cancelled,
}

enum EventCategory {
  seminar,
  workshop,
  cultural,
  competition,
  conference,
  ragDay,
  picnic,
  other,
}
