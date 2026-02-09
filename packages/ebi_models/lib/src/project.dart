/// Project phase in the supply chain.
enum ProjectPhase {
  design,
  sampling,
  tooling,
  production,
  qualityCheck,
  shipping,
  completed,
}

/// Represents a supply chain project.
class Project {
  final String id;
  final String projectName;
  final String? projectCode;
  final String? customerId;
  final String? customerName;
  final ProjectPhase currentPhase;
  final double progressPercent;
  final DateTime? startDate;
  final DateTime? estimatedEndDate;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    required this.id,
    required this.projectName,
    this.projectCode,
    this.customerId,
    this.customerName,
    required this.currentPhase,
    this.progressPercent = 0,
    this.startDate,
    this.estimatedEndDate,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      projectName: json['project_name'] as String,
      projectCode: json['project_code'] as String?,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      currentPhase: ProjectPhase.values.firstWhere(
        (e) => e.name == json['current_phase'],
        orElse: () => ProjectPhase.design,
      ),
      progressPercent:
          (json['progress_percent'] as num?)?.toDouble() ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      estimatedEndDate: json['estimated_end_date'] != null
          ? DateTime.parse(json['estimated_end_date'] as String)
          : null,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_name': projectName,
        'project_code': projectCode,
        'customer_id': customerId,
        'customer_name': customerName,
        'current_phase': currentPhase.name,
        'progress_percent': progressPercent,
        'start_date': startDate?.toIso8601String(),
        'estimated_end_date': estimatedEndDate?.toIso8601String(),
        'description': description,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
