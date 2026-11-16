/// Prototype domain models — typed data only; UI never touches raw fixtures.
library;

enum WorkArrangement { inHouse, clientSite }

enum EntryKind { work, breakEntry }

enum WorkLocation { office, home, clientSite }

enum TaskStatus { ongoing, done, blocked, dropped }

class Org {
  const Org({required this.id, required this.name, required this.kind});
  final String id;
  final String name;
  final String kind; // 'employer' | 'client'
}

class Project {
  const Project({required this.id, required this.name, required this.team});
  final String id;
  final String name;
  final String team;
}

class Subtask {
  const Subtask({required this.id, required this.title, this.status = TaskStatus.ongoing});
  final String id;
  final String title;
  final TaskStatus status;
}

class Task {
  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = TaskStatus.ongoing,
    List<Subtask>? subtasks,
    this.progressNotes = const [],
  }) : subtasks = subtasks ?? [];
  final String id;
  final String projectId;
  final String title;
  String description;
  final TaskStatus status;
  final List<Subtask> subtasks;
  final List<String> progressNotes;
}

class ClientCategory {
  const ClientCategory({required this.id, required this.name, required this.clientId});
  final String id;
  final String name;
  final String clientId;
}

class ClientSubcategory {
  const ClientSubcategory({required this.id, required this.categoryId, required this.name});
  final String id;
  final String categoryId;
  final String name;
}

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.department,
    required this.employerOrgId,
    this.clientOrgId,
    this.workArrangement = WorkArrangement.inHouse,
    this.photoUrl,
    this.scenario = '',
  });
  final String id;
  final String name;
  final String jobTitle;
  final String department;
  final String employerOrgId;
  final String? clientOrgId;
  final WorkArrangement workArrangement;
  final String? photoUrl;
  final String scenario;
}

class WorkEntry {
  WorkEntry({
    required this.id,
    required this.kind,
    required this.startMin, // minutes since midnight, Africa/Lagos
    required this.endMin,
    this.taskId,
    this.subtaskId,
    this.clientCategoryId,
    this.clientSubcategoryId,
    this.description = '',
    this.location = WorkLocation.office,
    this.isOvertime = false,
  });
  final String id;
  final EntryKind kind;
  final int startMin;
  final int endMin;
  final String? taskId;
  final String? subtaskId;
  final String? clientCategoryId;
  final String? clientSubcategoryId;
  String description;
  WorkLocation location;
  bool isOvertime;

  int get durationMin => endMin - startMin;
}

class ProtoState {
  const ProtoState({
    this.phase = ProtoPhase.welcome,
    this.scenario = '',
    this.employee,
    this.onboarding = const {},
    this.entries = const [],
    this.tasks = const [],
    this.selectedDateOffset = 0,
  });
  final ProtoPhase phase;
  final String scenario; // 'new' | 'invite' | 'returning'
  final Employee? employee;
  final Map<String, Object?> onboarding;
  final List<WorkEntry> entries;
  final List<Task> tasks;
  final int selectedDateOffset; // 0 = today
}

enum ProtoPhase { welcome, onboarding, home }
