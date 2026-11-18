/// Prototype domain models — typed data only; UI never touches raw fixtures.
library;

enum WorkArrangement { inHouse, clientSite }

enum EntryKind { work, breakEntry }

enum WorkLocation { office, home, clientSite }

enum TaskStatus { ongoing, done, blocked, dropped }

enum ComplaintStatus { newComplaint, inProgress, awaitingStaff, resolved, reopened }

/// A file attached to a work entry or complaint message (metadata only in the
/// prototype — real uploads go through the backend later).
class AttachmentItem {
  const AttachmentItem({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    this.addedAt,
    this.path,
  });
  final String id;
  final String fileName;
  final int sizeBytes;
  final DateTime? addedAt;

  /// Local file path for uploads picked on-device (null for server rows).
  final String? path;

  bool get isImage =>
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.webp');
}

/// A file attached to a complaint message.
class ComplaintFile {
  const ComplaintFile({required this.id, required this.fileName, required this.sizeBytes, this.path});
  final String id;
  final String fileName;
  final int sizeBytes;

  /// Local file path when the file was picked on-device and not yet uploaded.
  final String? path;
}

class ComplaintMessage {
  const ComplaintMessage({
    required this.id,
    required this.senderType, // 'staff' | 'management' | 'system'
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.senderRole,
    this.attachments = const [],
  });
  final String id;
  final String senderType;
  final String senderName;
  final String? senderRole;
  final String body;
  final DateTime createdAt;
  final List<ComplaintFile> attachments;
}

class Complaint {
  Complaint({
    required this.id,
    required this.reference,
    required this.subject,
    required this.status,
    required this.submittedAt,
    required this.lastMessageAt,
    required this.messages,
    this.unreadByStaff = false,
  });
  final String id;
  final String reference;
  final String subject;
  ComplaintStatus status;
  final DateTime submittedAt;
  DateTime lastMessageAt;
  final List<ComplaintMessage> messages;
  bool unreadByStaff;

  Complaint copyWith({ComplaintStatus? status, DateTime? lastMessageAt, List<ComplaintMessage>? messages, bool? unreadByStaff}) =>
      Complaint(
        id: id,
        reference: reference,
        subject: subject,
        status: status ?? this.status,
        submittedAt: submittedAt,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        messages: messages ?? this.messages,
        unreadByStaff: unreadByStaff ?? this.unreadByStaff,
      );
}

/// Live break — persisted start timestamp drives the countdown, mirroring the
/// web behaviour (no auto-end; overrun is displayed).
class ActiveBreak {
  const ActiveBreak({required this.startedAt, this.id});
  final DateTime startedAt;

  /// Backend break-entry id — required to end the break via the API.
  final String? id;
}

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
    required this.date,
    required this.startMin, // minutes since midnight, Africa/Lagos
    required this.endMin,
    this.taskId,
    this.subtaskId,
    this.clientCategoryId,
    this.clientSubcategoryId,
    this.description = '',
    this.location = WorkLocation.office,
    this.isOvertime = false,
    this.attachments = const [],
    this.evidenceLink,
  });
  final String id;
  final EntryKind kind;
  final DateTime date; // day of the entry
  final int startMin;
  final int endMin;
  final String? taskId;
  final String? subtaskId;
  final String? clientCategoryId;
  final String? clientSubcategoryId;
  String description;
  WorkLocation location;
  bool isOvertime;
  List<AttachmentItem> attachments;
  String? evidenceLink;

  int get durationMin => endMin - startMin;

  DateTime get day => DateTime(date.year, date.month, date.day);

  WorkEntry copyWith({
    DateTime? date,
    int? startMin,
    int? endMin,
    String? taskId,
    String? subtaskId,
    String? clientCategoryId,
    String? clientSubcategoryId,
    String? description,
    WorkLocation? location,
    bool? isOvertime,
    List<AttachmentItem>? attachments,
    String? evidenceLink,
    bool clearEvidenceLink = false,
  }) {
    return WorkEntry(
      id: id,
      kind: kind,
      date: date ?? this.date,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      taskId: taskId ?? this.taskId,
      subtaskId: subtaskId ?? this.subtaskId,
      clientCategoryId: clientCategoryId ?? this.clientCategoryId,
      clientSubcategoryId: clientSubcategoryId ?? this.clientSubcategoryId,
      description: description ?? this.description,
      location: location ?? this.location,
      isOvertime: isOvertime ?? this.isOvertime,
      attachments: attachments ?? this.attachments,
      evidenceLink: clearEvidenceLink ? null : (evidenceLink ?? this.evidenceLink),
    );
  }
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
    this.complaints = const [],
    this.activeBreak,
    this.projects = const [],
    this.clientCategories = const [],
    this.clientSubcategories = const [],
    this.orgNames = const {},
    this.liveError,
    this.liveBusy = false,
  });
  final ProtoPhase phase;
  final String scenario; // 'new' | 'invite' | 'returning' | 'live'
  final Employee? employee;
  final Map<String, Object?> onboarding;
  final List<WorkEntry> entries;
  final List<Task> tasks;
  final int selectedDateOffset; // 0 = today
  final List<Complaint> complaints;
  final ActiveBreak? activeBreak;

  /// Live-mode lookup data hydrated from GET /api/worklog/state.
  final List<Project> projects;
  final List<ClientCategory> clientCategories;
  final List<ClientSubcategory> clientSubcategories;
  final Map<String, String> orgNames;

  /// Last live-API error surfaced to the user; cleared on next success.
  final String? liveError;
  final bool liveBusy;

  bool get isLive => scenario == 'live';

  int get unreadComplaintCount => complaints.where((c) => c.unreadByStaff).length;
}

enum ProtoPhase { welcome, onboarding, home }
