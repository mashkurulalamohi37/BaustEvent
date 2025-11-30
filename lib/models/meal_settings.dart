import 'package:cloud_firestore/cloud_firestore.dart';

class MealSettings {
  final bool isMealEnabled;
  final DateTime? closeTime;
  final String? notice;
  final DateTime? updatedAt;

  const MealSettings({
    required this.isMealEnabled,
    this.closeTime,
    this.notice,
    this.updatedAt,
  });

  factory MealSettings.initial() {
    return const MealSettings(isMealEnabled: false);
  }

  MealSettings copyWith({
    bool? isMealEnabled,
    DateTime? closeTime,
    bool closeTimeSet = false,
    String? notice,
    bool noticeSet = false,
    DateTime? updatedAt,
  }) {
    return MealSettings(
      isMealEnabled: isMealEnabled ?? this.isMealEnabled,
      closeTime: closeTimeSet ? closeTime : (closeTime ?? this.closeTime),
      notice: noticeSet ? notice : (notice ?? this.notice),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mealEnabled': isMealEnabled,
      'mealCloseTime': closeTime?.toIso8601String(),
      if (notice != null && notice!.isNotEmpty) 'mealNotice': notice,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MealSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return MealSettings.initial();
    return MealSettings.fromMap(data);
  }

  factory MealSettings.fromMap(Map<String, dynamic> data) {
    DateTime? _parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      try {
        final toDate = raw.toDate();
        if (toDate is DateTime) return toDate;
      } catch (_) {}
      return null;
    }

    return MealSettings(
      isMealEnabled: data['mealEnabled'] as bool? ?? false,
      closeTime: _parseDate(data['mealCloseTime']),
      notice: data['mealNotice'] as String?,
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  bool get isMealCurrentlyAvailable {
    if (!isMealEnabled) return false;
    if (closeTime == null) return true;
    return DateTime.now().isBefore(closeTime!);
  }

  Duration? get timeUntilClose {
    if (!isMealCurrentlyAvailable) return null;
    if (closeTime == null) return null;
    return closeTime!.difference(DateTime.now());
  }
}
