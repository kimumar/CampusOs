class CampusCourse {
  const CampusCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.units,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncVersion = 0,
  });

  final String id;
  final String code;
  final String title;
  final int units;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int syncVersion;

  CampusCourse copyWith({
    String? id,
    String? code,
    String? title,
    int? units,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? syncVersion,
  }) {
    return CampusCourse(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      units: units ?? this.units,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'units': units,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
    };
  }

  factory CampusCourse.fromMap(Map<String, dynamic> map) {
    return CampusCourse(
      id: map['id'] as String,
      code: map['code'] as String,
      title: map['title'] as String,
      units: (map['units'] as num).toInt(),
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] as String,
      ),
      isDeleted: map['is_deleted'] == true ||
          map['is_deleted'] == 1,
      syncVersion:
          (map['sync_version'] as num?)?.toInt() ?? 0,
    );
  }
}