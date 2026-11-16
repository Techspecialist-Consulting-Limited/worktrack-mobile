// Models mirroring the backend's mobile API responses.
// The backend remains authoritative — these are display DTOs only.

class MembershipInfo {
  const MembershipInfo({
    required this.role,
    required this.isConfigAdmin,
    required this.employeeId,
    required this.activeTeamId,
    required this.employeeName,
  });

  final String role;
  final bool isConfigAdmin;
  final String? employeeId;
  final String? activeTeamId;
  final String? employeeName;

  factory MembershipInfo.fromJson(Map<String, dynamic> json) => MembershipInfo(
        role: json['role'] as String? ?? '',
        isConfigAdmin: json['isConfigAdmin'] as bool? ?? false,
        employeeId: json['employeeId'] as String?,
        activeTeamId: json['activeTeamId'] as String?,
        employeeName: json['employeeName'] as String?,
      );

  String get roleLabel => switch (role) {
        'staff' => 'Staff',
        'hr' => 'HR',
        'chairman' => 'Chairman',
        _ => role,
      };
}

class SessionInfo {
  const SessionInfo({
    required this.name,
    required this.email,
    required this.memberships,
    required this.accessState,
  });

  final String? name;
  final String? email;
  final List<MembershipInfo> memberships;

  /// Backend-reported lifecycle state: "active" | "deactivated" | "none".
  /// "none" means the identity must complete self-service onboarding.
  final String accessState;

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    final identity = json['identity'] as Map<String, dynamic>? ?? const {};
    final raw = json['memberships'] as List? ?? const [];
    return SessionInfo(
      name: identity['name'] as String?,
      email: identity['email'] as String?,
      memberships: raw
          .whereType<Map>()
          .map((m) => MembershipInfo.fromJson(m.cast<String, dynamic>()))
          .toList(),
      accessState: json['accessState'] as String? ?? 'none',
    );
  }
}

/// Minimal projection of GET /api/worklog/state for diagnostics display.
class WorklogStateSummary {
  const WorklogStateSummary({
    required this.employeeCount,
    required this.taskCount,
    required this.entryCount,
    required this.breakCount,
    required this.firstEmployeeName,
    required this.role,
    required this.isConfigAdmin,
  });

  final int employeeCount;
  final int taskCount;
  final int entryCount;
  final int breakCount;
  final String? firstEmployeeName;
  final String? role;
  final bool isConfigAdmin;

  factory WorklogStateSummary.fromResponse(Map<String, dynamic> json) {
    final db = json['db'] as Map<String, dynamic>? ?? const {};
    int count(String key) => (db[key] as List?)?.length ?? 0;
    final employees = db['employees'] as List? ?? const [];
    String? name;
    if (employees.isNotEmpty) {
      final first = employees.first;
      if (first is Map) {
        name = (first['fullName'] ?? first['name']) as String?;
      }
    }
    return WorklogStateSummary(
      employeeCount: count('employees'),
      taskCount: count('tasks'),
      entryCount: count('entries'),
      breakCount: count('breaks'),
      firstEmployeeName: name,
      role: json['role'] as String?,
      isConfigAdmin: json['isConfigAdmin'] as bool? ?? false,
    );
  }
}
