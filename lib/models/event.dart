
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
