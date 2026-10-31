import 'package:flutter/foundation.dart';

/// A report recorded by the mock safety repository. It never leaves this
/// device and is never delivered to moderators.
@immutable
class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.category,
    required this.createdAt,
    this.details = '',
    this.attachmentAsset,
    this.subjectName,
  });

  final String id;
  final String category;
  final DateTime createdAt;
  final String details;

  /// Local sample photo path. Nothing is uploaded.
  final String? attachmentAsset;

  /// Public display name only; never a phone number or exact location.
  final String? subjectName;
}
