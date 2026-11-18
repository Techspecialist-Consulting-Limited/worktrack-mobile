/// Maps the backend `WorkLogDatabase` JSON (GET /api/worklog/state → `db`)
/// into the proto models the screens already render. Africa/Lagos is a fixed
/// UTC+1 offset (no DST), so conversion is a plain shift — the backend stays
/// authoritative for all calculations.
library;

import 'models.dart';

/// Parses an ISO timestamp and returns the equivalent Africa/Lagos wall time.
DateTime lagosTime(String iso) =>
    DateTime.parse(iso).toUtc().add(const Duration(hours: 1));

int _mins(DateTime d) => d.hour * 60 + d.minute;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

WorkLocation _mapLocation(String? raw, WorkArrangement arrangement) {
  return switch (raw) {
    'home' => WorkLocation.home,
    'other' || 'unknown' =>
      arrangement == WorkArrangement.clientSite ? WorkLocation.clientSite : WorkLocation.office,
    _ => WorkLocation.office,
  };
}

TaskStatus _mapStatus(String? raw) => switch (raw) {
      'done' => TaskStatus.done,
      'blocked' => TaskStatus.blocked,
      'dropped' => TaskStatus.dropped,
      _ => TaskStatus.ongoing,
    };

ComplaintStatus _mapComplaintStatus(String? raw) => switch (raw) {
      'in_progress' => ComplaintStatus.inProgress,
      'awaiting_staff' => ComplaintStatus.awaitingStaff,
      'resolved' => ComplaintStatus.resolved,
      'reopened' => ComplaintStatus.reopened,
      _ => ComplaintStatus.newComplaint,
    };

List<Map<String, dynamic>> _maps(dynamic v) =>
    (v as List? ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();

String? _str(Map<String, dynamic> m, String key) => m[key] as String?;

/// Result of mapping a worklog-state snapshot.
class LiveSnapshot {
  const LiveSnapshot({
    required this.employee,
    required this.entries,
    required this.tasks,
    required this.projects,
    required this.clientCategories,
    required this.clientSubcategories,
    required this.orgNames,
    required this.activeBreak,
  });

  final Employee employee;
  final List<WorkEntry> entries;
  final List<Task> tasks;
  final List<Project> projects;
  final List<ClientCategory> clientCategories;
  final List<ClientSubcategory> clientSubcategories;
  final Map<String, String> orgNames;
  final ActiveBreak? activeBreak;
}

LiveSnapshot mapWorklogDb(Map<String, dynamic> db) {
  final orgNames = <String, String>{
    for (final o in _maps(db['organisations']))
      if (_str(o, 'id') != null) _str(o, 'id')!: _str(o, 'name') ?? '',
  };

  final teams = {
    for (final t in _maps(db['teams'])) _str(t, 'id')!: _str(t, 'name') ?? '',
  };
  final projects = [
    for (final p in _maps(db['projects']))
      if (p['isActive'] != false && _str(p, 'id') != null)
        Project(
          id: _str(p, 'id')!,
          name: _str(p, 'name') ?? 'Project',
          team: teams[_str(p, 'teamId')] ?? '',
        ),
  ];

  // Staff scope returns only the signed-in employee; take the first record.
  final empJson = _maps(db['employees']).firstOrNull ?? const <String, dynamic>{};
  final arrangement = _str(empJson, 'workArrangement') == 'client_site'
      ? WorkArrangement.clientSite
      : WorkArrangement.inHouse;
  final employee = Employee(
    id: _str(empJson, 'id') ?? '',
    name: _str(empJson, 'name') ?? 'Team Member',
    jobTitle: _str(empJson, 'role') ?? '',
    department: _str(empJson, 'department') ?? '',
    employerOrgId: _str(empJson, 'employerOrganisationId') ?? '',
    clientOrgId: _str(empJson, 'clientOrganisationId'),
    workArrangement: arrangement,
  );

  final attachmentsByEntry = <String, List<AttachmentItem>>{};
  for (final a in _maps(db['attachments'])) {
    final entryId = _str(a, 'entryId');
    if (entryId == null) continue;
    attachmentsByEntry.putIfAbsent(entryId, () => []).add(AttachmentItem(
          id: _str(a, 'id') ?? '',
          fileName: _str(a, 'fileName') ?? 'file',
          sizeBytes: (a['sizeBytes'] as num?)?.toInt() ?? 0,
          addedAt: _tryDate(_str(a, 'createdAt')),
        ));
  }

  final entries = <WorkEntry>[];
  ActiveBreak? activeBreak;
  for (final e in _maps(db['entries'])) {
    final startIso = _str(e, 'startAt');
    if (startIso == null) continue;
    final start = lagosTime(startIso);
    final endIso = _str(e, 'endAt');
    final end = endIso != null ? lagosTime(endIso) : DateTime.now();
    final id = _str(e, 'id') ?? '';
    entries.add(WorkEntry(
      id: id,
      kind: EntryKind.work,
      date: _dayOf(start),
      startMin: _mins(start),
      endMin: _mins(end),
      taskId: _str(e, 'taskId'),
      subtaskId: _str(e, 'subtaskId'),
      clientCategoryId: _str(e, 'clientCategoryId'),
      clientSubcategoryId: _str(e, 'clientSubcategoryId'),
      description: _str(e, 'description') ?? '',
      location: _mapLocation(_str(e, 'workLocation'), arrangement),
      isOvertime: (e['isReportedOvertime'] == true) || ((e['overtimeMinutes'] as num?) ?? 0) > 0,
      attachments: attachmentsByEntry[id] ?? const [],
      evidenceLink: _str(e, 'evidenceLink'),
    ));
  }
  for (final b in _maps(db['breaks'])) {
    final startIso = _str(b, 'startAt');
    if (startIso == null) continue;
    final start = lagosTime(startIso);
    final endIso = _str(b, 'endAt');
    if (endIso == null) {
      activeBreak = ActiveBreak(startedAt: start, id: _str(b, 'id'));
      continue;
    }
    final end = lagosTime(endIso);
    entries.add(WorkEntry(
      id: _str(b, 'id') ?? '',
      kind: EntryKind.breakEntry,
      date: _dayOf(start),
      startMin: _mins(start),
      endMin: _mins(end),
      location: WorkLocation.office,
    ));
  }

  // Subtasks + progress updates grouped by task.
  final subtasksByTask = <String, List<Subtask>>{};
  for (final s in _maps(db['subtasks'])) {
    if (s['archivedAt'] != null) continue;
    final taskId = _str(s, 'taskId');
    if (taskId == null) continue;
    subtasksByTask.putIfAbsent(taskId, () => []).add(Subtask(
          id: _str(s, 'id') ?? '',
          title: _str(s, 'title') ?? '',
          status: _mapStatus(_str(s, 'status')),
        ));
  }
  final notesByTask = <String, List<String>>{};
  for (final u in _maps(db['progressUpdates'])) {
    final taskId = _str(u, 'taskId');
    final body = _str(u, 'body');
    if (taskId == null || body == null || body.isEmpty) continue;
    final author = _str(u, 'authorName');
    notesByTask.putIfAbsent(taskId, () => []).add(author == null ? body : '$author: $body');
  }

  final tasks = <Task>[
    for (final t in _maps(db['tasks']))
      if (t['archivedAt'] == null && _str(t, 'id') != null)
        Task(
          id: _str(t, 'id')!,
          projectId: _str(t, 'projectId') ?? '',
          title: _str(t, 'title') ?? 'Task',
          description: _str(t, 'description') ?? '',
          status: _mapStatus(_str(t, 'currentStatus')),
          subtasks: subtasksByTask[_str(t, 'id')] ?? const [],
          progressNotes: notesByTask[_str(t, 'id')] ?? const [],
        ),
  ];

  final clientOrgId = employee.clientOrgId;
  final clientCategories = [
    for (final c in _maps(db['clientCategories']))
      if (c['isActive'] == true &&
          c['approvalStatus'] == 'approved' &&
          _str(c, 'clientOrganisationId') == clientOrgId &&
          _str(c, 'id') != null)
        ClientCategory(id: _str(c, 'id')!, name: _str(c, 'name') ?? '', clientId: clientOrgId ?? ''),
  ];
  final clientSubcategories = [
    for (final s in _maps(db['clientSubcategories']))
      if (s['isActive'] == true &&
          s['approvalStatus'] == 'approved' &&
          _str(s, 'clientOrganisationId') == clientOrgId &&
          _str(s, 'id') != null)
        ClientSubcategory(
          id: _str(s, 'id')!,
          categoryId: _str(s, 'categoryId') ?? '',
          name: _str(s, 'name') ?? '',
        ),
  ];

  return LiveSnapshot(
    employee: employee,
    entries: entries,
    tasks: tasks,
    projects: projects,
    clientCategories: clientCategories,
    clientSubcategories: clientSubcategories,
    orgNames: orgNames,
    activeBreak: activeBreak,
  );
}

/// Maps GET /api/complaints records into proto complaints.
List<Complaint> mapComplaints(List<Map<String, dynamic>> records) {
  ComplaintMessage mapMessage(Map<String, dynamic> m) => ComplaintMessage(
        id: _str(m, 'id') ?? '',
        senderType: _str(m, 'senderType') ?? 'staff',
        senderName: _str(m, 'senderName') ?? '',
        senderRole: _str(m, 'senderRole'),
        body: _str(m, 'body') ?? '',
        createdAt: _tryDate(_str(m, 'createdAt')) ?? DateTime.now(),
        attachments: [
          for (final a in _maps(m['attachments']))
            ComplaintFile(
              id: _str(a, 'id') ?? '',
              fileName: _str(a, 'fileName') ?? 'file',
              sizeBytes: (a['sizeBytes'] as num?)?.toInt() ?? 0,
            ),
        ],
      );

  return [
    for (final c in records)
      Complaint(
        id: _str(c, 'id') ?? '',
        reference: _str(c, 'reference') ?? '',
        subject: _str(c, 'subject') ?? '',
        status: _mapComplaintStatus(_str(c, 'status')),
        submittedAt: _tryDate(_str(c, 'submittedAt')) ?? DateTime.now(),
        lastMessageAt: _tryDate(_str(c, 'lastMessageAt')) ?? DateTime.now(),
        unreadByStaff: c['unreadByStaff'] == true,
        messages: [
          for (final m in _maps(c['messages'])) mapMessage(m),
        ],
      ),
  ];
}

DateTime? _tryDate(String? iso) {
  if (iso == null) return null;
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return null;
  }
}
