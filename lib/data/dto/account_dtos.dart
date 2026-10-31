import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/safety_report.dart';
import '../models/user_preferences.dart';
import 'json_codec.dart';
import 'typed_values.dart';

@immutable
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final NotificationId id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  factory NotificationDto.fromJson(Object? json) =>
      NotificationDto.fromMap(JsonMap.from(json));

  factory NotificationDto.fromMap(JsonMap map) {
    map.rejectPrivateFields(const ['phone', 'e164', 'latitude', 'longitude']);
    return NotificationDto(
      id: readNotificationId(map),
      type: map.enumValue('type', NotificationType.values),
      title: map.string('title'),
      body: map.string('body'),
      createdAt: map.dateTime('createdAt'),
      isRead: map.optionalBoolean('isRead') ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'isRead': isRead,
  };

  AppNotification toDomain() => AppNotification(
    id: id.raw,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead,
  );
}

@immutable
class SafetyReportDto {
  const SafetyReportDto({
    required this.id,
    required this.category,
    required this.createdAt,
    this.details = '',
    this.subjectName,
  });

  final ReportId id;
  final String category;
  final DateTime createdAt;
  final String details;
  final String? subjectName;

  factory SafetyReportDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    map.rejectPrivateFields(const ['phone', 'e164', 'latitude', 'longitude']);
    return SafetyReportDto(
      id: readReportId(map),
      category: map.string('category'),
      createdAt: map.dateTime('createdAt'),
      details: map.optionalString('details', allowEmpty: true) ?? '',
      subjectName: map.optionalString('subjectName'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'category': category,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'details': details,
    'subjectName': subjectName,
  };

  SafetyReport toDomain() => SafetyReport(
    id: id.raw,
    category: category,
    createdAt: createdAt,
    details: details,
    subjectName: subjectName,
  );
}

@immutable
class ReportRequestDto {
  const ReportRequestDto({
    required this.category,
    this.details = '',
    this.subjectName,
  });

  final String category;
  final String details;
  final String? subjectName;

  factory ReportRequestDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return ReportRequestDto(
      category: map.string('category'),
      details: map.optionalString('details', allowEmpty: true) ?? '',
      subjectName: map.optionalString('subjectName'),
    );
  }

  Map<String, Object?> toJson() => {
    'category': category,
    'details': details,
    'subjectName': subjectName,
  };
}

/// Remote account settings. Phone is a masked label only. Exact location and
/// E.164 numbers are rejected.
@immutable
class AccountSettingsDto {
  const AccountSettingsDto({
    required this.id,
    this.phoneLabel,
    this.showInDiscovery = true,
    this.showApproximateDistance = true,
    this.showActiveStatus = true,
    this.showOccupation = true,
  });

  final AccountId id;
  final String? phoneLabel;
  final bool showInDiscovery;
  final bool showApproximateDistance;
  final bool showActiveStatus;
  final bool showOccupation;

  factory AccountSettingsDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    map.rejectPrivateFields(const [
      'phone',
      'e164',
      'birthDate',
      'dateOfBirth',
      'latitude',
      'longitude',
    ]);
    return AccountSettingsDto(
      id: readAccountId(map),
      phoneLabel: map.optionalString('phoneLabel'),
      showInDiscovery: map.optionalBoolean('showInDiscovery') ?? true,
      showApproximateDistance:
          map.optionalBoolean('showApproximateDistance') ?? true,
      showActiveStatus: map.optionalBoolean('showActiveStatus') ?? true,
      showOccupation: map.optionalBoolean('showOccupation') ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'phoneLabel': phoneLabel,
    'showInDiscovery': showInDiscovery,
    'showApproximateDistance': showApproximateDistance,
    'showActiveStatus': showActiveStatus,
    'showOccupation': showOccupation,
  };

  UserPreferences toPreferences(UserPreferences current) => current.copyWith(
    showInDiscovery: showInDiscovery,
    showApproximateDistance: showApproximateDistance,
    showActiveStatus: showActiveStatus,
    showOccupation: showOccupation,
  );
}
