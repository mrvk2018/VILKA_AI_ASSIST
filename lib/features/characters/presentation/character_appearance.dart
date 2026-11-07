import 'package:flutter/material.dart';

/// Настроение по уровню привязанности.
({String label, String emoji}) moodOf(double affection) {
  if (affection < 0.3) return (label: 'Холодно', emoji: '😠');
  if (affection < 0.55) return (label: 'Ровно', emoji: '😐');
  if (affection < 0.8) return (label: 'Тепло', emoji: '🙂');
  return (label: 'Близко', emoji: '🥰');
}

IconData iconForCharacter(String? id) {
  return switch (id) {
    'moody_wife' => Icons.mood_bad_outlined,
    'street_wife' => Icons.local_fire_department_outlined,
    'teacher_wife' => Icons.school_outlined,
    'shy_wife' => Icons.favorite_border,
    _ => Icons.person_outline,
  };
}
