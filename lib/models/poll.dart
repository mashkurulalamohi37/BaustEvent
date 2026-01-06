class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final String creatorId;
  final String? eventId; // Optional: Associate with a specific event
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool allowMultipleVotes;
  final bool isAnonymous;
  final PollStatus status;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.creatorId,
    this.eventId,
    required this.createdAt,
    required this.expiresAt,
    this.allowMultipleVotes = false,
    this.isAnonymous = false,
    this.status = PollStatus.active,
  });

  // Calculate total votes
  int get totalVotes => options.fold(0, (sum, option) => sum + option.votes);

  // Check if poll has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Check if poll is still active
  bool get isActive => status == PollStatus.active && !isExpired;

  // Get time remaining until expiry
  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((o) => o.toJson()).toList(),
      'creatorId': creatorId,
      'eventId': eventId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'allowMultipleVotes': allowMultipleVotes,
      'isAnonymous': isAnonymous,
      'status': status.name,
    };
  }

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'],
      question: json['question'],
      options: (json['options'] as List)
          .map((o) => PollOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      creatorId: json['creatorId'],
      eventId: json['eventId'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      allowMultipleVotes: json['allowMultipleVotes'] ?? false,
      isAnonymous: json['isAnonymous'] ?? false,
      status: PollStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PollStatus.active,
      ),
    );
  }

  Poll copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    String? creatorId,
    String? eventId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? allowMultipleVotes,
    bool? isAnonymous,
    PollStatus? status,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      creatorId: creatorId ?? this.creatorId,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      allowMultipleVotes: allowMultipleVotes ?? this.allowMultipleVotes,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      status: status ?? this.status,
    );
  }
}

class PollOption {
  final String id;
  final String text;
  final int votes;
  final List<String> voterIds; // Track who voted (if not anonymous)

  PollOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.voterIds = const [],
  });

  // Calculate percentage of total votes
  double getPercentage(int totalVotes) {
    if (totalVotes == 0) return 0.0;
    return (votes / totalVotes) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
      'voterIds': voterIds,
    };
  }

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'],
      text: json['text'],
      votes: json['votes'] ?? 0,
      voterIds: List<String>.from(json['voterIds'] ?? []),
    );
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? votes,
    List<String>? voterIds,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      voterIds: voterIds ?? this.voterIds,
    );
  }
}

enum PollStatus {
  active,
  closed,
  cancelled,
}

// Firestore helpers
extension PollFirestore on Poll {
  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options.map((o) => o.toJson()).toList(),
      'creatorId': creatorId,
      'eventId': eventId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'allowMultipleVotes': allowMultipleVotes,
      'isAnonymous': isAnonymous,
      'status': status.name,
    };
  }

  static Poll fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String id = doc.id as String;

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
      try {
        final toDate = raw.toDate();
        if (toDate is DateTime) return toDate;
      } catch (_) {}
      return DateTime.now();
    }

    return Poll(
      id: id,
      question: data['question'] ?? '',
      options: (data['options'] as List?)
              ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      creatorId: data['creatorId'] ?? '',
      eventId: data['eventId'],
      createdAt: _parseDate(data['createdAt']),
      expiresAt: _parseDate(data['expiresAt']),
      allowMultipleVotes: data['allowMultipleVotes'] ?? false,
      isAnonymous: data['isAnonymous'] ?? false,
      status: PollStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => PollStatus.active,
      ),
    );
  }
}
