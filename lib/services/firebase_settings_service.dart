import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_settings.dart';

class FirebaseSettingsService {
  FirebaseSettingsService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'app_settings';
  static const String _mealDocId = 'meal_settings';

  static DocumentReference<Map<String, dynamic>> get _mealSettingsDoc =>
      _firestore.collection(_collectionName).doc(_mealDocId);

  static Future<MealSettings> getMealSettings() async {
    final doc = await _mealSettingsDoc.get();
    if (!doc.exists || doc.data() == null) {
      final defaults = MealSettings.initial();
      await _mealSettingsDoc.set({
        'mealEnabled': defaults.isMealEnabled,
        'mealCloseTime': defaults.closeTime?.toIso8601String(),
        'mealNotice': defaults.notice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return defaults;
    }
    return MealSettings.fromDoc(doc);
  }

  static Stream<MealSettings> mealSettingsStream() {
    return _mealSettingsDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return MealSettings.initial();
      }
      return MealSettings.fromDoc(doc);
    });
  }

  static Future<void> updateMealSettings({
    bool? mealEnabled,
    DateTime? closeTime,
    String? notice,
    bool clearCloseTime = false,
    bool clearNotice = false,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (mealEnabled != null) {
      data['mealEnabled'] = mealEnabled;
    }

    if (clearCloseTime) {
      data['mealCloseTime'] = null;
    } else if (closeTime != null) {
      data['mealCloseTime'] = closeTime.toIso8601String();
    }

    if (clearNotice) {
      data['mealNotice'] = null;
    } else if (notice != null) {
      data['mealNotice'] = notice.trim().isEmpty ? null : notice.trim();
    }

    await _mealSettingsDoc.set(data, SetOptions(merge: true));
  }
}
