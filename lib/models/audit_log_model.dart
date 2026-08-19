import 'dart:convert';

class AuditLog {
  final String id;
  final String? userId;
  final String userEmail;
  final String userName;
  final String userRole;
  final String action;
  final String module;
  final String description;
  final String? entityId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.userId,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.module,
    required this.description,
    this.entityId,
    this.metadata = const {},
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedMeta = {};
    if (json['metadata'] != null) {
      if (json['metadata'] is Map) {
        parsedMeta = Map<String, dynamic>.from(json['metadata']);
      } else if (json['metadata'] is String) {
        try {
          parsedMeta = Map<String, dynamic>.from(jsonDecode(json['metadata']));
        } catch (_) {}
      }
    }

    return AuditLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userEmail: json['user_email']?.toString() ?? 'unknown@system.local',
      userName: json['user_name']?.toString() ?? (json['user_email']?.toString().split('@').first ?? 'Staff User'),
      userRole: json['user_role']?.toString().toUpperCase() ?? 'STAFF',
      action: json['action']?.toString().toUpperCase() ?? 'UNKNOWN',
      module: json['module']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      entityId: json['entity_id']?.toString(),
      metadata: parsedMeta,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'user_role': userRole,
      'action': action,
      'module': module,
      'description': description,
      'entity_id': entityId,
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
