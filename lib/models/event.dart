
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

  const Event({
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
  });

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
    );
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
  other,
}
