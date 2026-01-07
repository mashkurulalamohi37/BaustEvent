class EventItem {
  final String id;
  final String eventId;
  final String name;
  final String description;
  final String? imageUrl;
  final int totalQuantity;
  final int distributedQuantity;
  final DateTime createdAt;
  final String createdBy;

  EventItem({
    required this.id,
    required this.eventId,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.totalQuantity,
    this.distributedQuantity = 0,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'totalQuantity': totalQuantity,
      'distributedQuantity': distributedQuantity,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      totalQuantity: json['totalQuantity'] as int? ?? 0,
      distributedQuantity: json['distributedQuantity'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
    );
  }

  int get remainingQuantity => totalQuantity - distributedQuantity;
  double get distributionProgress => 
      totalQuantity > 0 ? (distributedQuantity / totalQuantity) : 0.0;
}

class ItemDistribution {
  final String id;
  final String eventId;
  final String itemId;
  final String participantId;
  final String participantName;
  final String participantEmail;
  final String universityId;
  final String batch;
  final String section;
  final DateTime distributedAt;
  final String distributedBy;
  final String? notes;

  ItemDistribution({
    required this.id,
    required this.eventId,
    required this.itemId,
    required this.participantId,
    required this.participantName,
    required this.participantEmail,
    required this.universityId,
    required this.batch,
    required this.section,
    required this.distributedAt,
    required this.distributedBy,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'itemId': itemId,
      'participantId': participantId,
      'participantName': participantName,
      'participantEmail': participantEmail,
      'universityId': universityId,
      'batch': batch,
      'section': section,
      'distributedAt': distributedAt.toIso8601String(),
      'distributedBy': distributedBy,
      'notes': notes,
    };
  }

  factory ItemDistribution.fromJson(Map<String, dynamic> json) {
    return ItemDistribution(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      itemId: json['itemId'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      participantEmail: json['participantEmail'] as String,
      universityId: json['universityId'] as String,
      batch: json['batch'] as String,
      section: json['section'] as String,
      distributedAt: DateTime.parse(json['distributedAt'] as String),
      distributedBy: json['distributedBy'] as String,
      notes: json['notes'] as String?,
    );
  }
}
