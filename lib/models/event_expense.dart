class EventExpense {
  final String id;
  final String eventId;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final String? receiptUrl;
  final PaymentMethod paymentMethod;
  final String? notes;

  EventExpense({
    required this.id,
    required this.eventId,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.receiptUrl,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'category': category.name,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'receiptUrl': receiptUrl,
      'paymentMethod': paymentMethod.name,
      'notes': notes,
    };
  }

  factory EventExpense.fromJson(Map<String, dynamic> json) {
    return EventExpense(
      id: json['id'],
      eventId: json['eventId'],
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: json['description'],
      amount: json['amount'] is int 
          ? (json['amount'] as int).toDouble() 
          : json['amount'] as double,
      date: DateTime.parse(json['date']),
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      receiptUrl: json['receiptUrl'],
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      notes: json['notes'],
    );
  }

  // Firestore helpers
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'category': category.name,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'receiptUrl': receiptUrl,
      'paymentMethod': paymentMethod.name,
      'notes': notes,
    };
  }

  static EventExpense fromFirestore(dynamic doc) {
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

    return EventExpense(
      id: id,
      eventId: data['eventId'] ?? '',
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: data['description'] ?? '',
      amount: data['amount'] is int 
          ? (data['amount'] as int).toDouble() 
          : (data['amount'] as double? ?? 0.0),
      date: _parseDate(data['date']),
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      receiptUrl: data['receiptUrl'] as String?,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      notes: data['notes'] as String?,
    );
  }

  EventExpense copyWith({
    String? id,
    String? eventId,
    ExpenseCategory? category,
    String? description,
    double? amount,
    DateTime? date,
    String? createdBy,
    DateTime? createdAt,
    String? receiptUrl,
    PaymentMethod? paymentMethod,
    String? notes,
    bool clearReceiptUrl = false,
    bool clearNotes = false,
  }) {
    return EventExpense(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      receiptUrl: clearReceiptUrl ? null : (receiptUrl ?? this.receiptUrl),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

enum ExpenseCategory {
  venue,
  catering,
  equipment,
  marketing,
  transportation,
  staff,
  decorations,
  prizes,
  printing,
  other,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.venue:
        return 'Venue';
      case ExpenseCategory.catering:
        return 'Catering';
      case ExpenseCategory.equipment:
        return 'Equipment';
      case ExpenseCategory.marketing:
        return 'Marketing';
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.staff:
        return 'Staff';
      case ExpenseCategory.decorations:
        return 'Decorations';
      case ExpenseCategory.prizes:
        return 'Prizes';
      case ExpenseCategory.printing:
        return 'Printing';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

enum PaymentMethod {
  cash,
  bkash,
  nagad,
  bankTransfer,
  card,
  other,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bkash:
        return 'bKash';
      case PaymentMethod.nagad:
        return 'Nagad';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}
