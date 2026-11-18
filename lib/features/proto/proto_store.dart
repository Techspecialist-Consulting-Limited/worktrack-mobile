import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/session_service.dart' show ApiException, SessionService;
import 'live_mapping.dart';
import 'mock_data.dart';
import 'models.dart';

/// Prototype session + worklog store. Two modes share one state shape:
///
/// * Demo (`scenario != 'live'`) — fully local mock data for UI development.
/// * Live (`scenario == 'live'`) — hydrated from GET /api/worklog/state and
///   every mutation is dispatched to POST /api/worklog/action (or the
///   complaints endpoints); the returned snapshot replaces local state, so
///   the server stays authoritative for validation, overlap rules and audit.
class ProtoStore extends Notifier<ProtoState> {
  static const workStart = 9 * 60; // 09:00 Africa/Lagos
  static const workEnd = 17 * 60; // 17:00

  @override
  ProtoState build() {
    ref.listen<AuthState>(authControllerProvider, (prev, next) => _onAuth(next));
    return const ProtoState();
  }

  SessionService get _api => ref.read(authControllerProvider.notifier).sessionService;

  /* ---------------- auth bridge ---------------- */

  void _onAuth(AuthState s) {
    if (s.phase == AuthPhase.ready && s.selectedMembership != null) {
      if (state.scenario != 'live' || state.employee == null) {
        unawaited(_hydrateLive());
      }
      return;
    }
    if ((s.phase == AuthPhase.signedOut || s.phase == AuthPhase.selectingRole) &&
        state.scenario == 'live') {
      state = const ProtoState();
    }
  }

  Future<void> _hydrateLive() async {
    state = _copy(liveBusy: true, clearLiveError: true);
    try {
      final res = await _api.fetchWorklogState();
      final db = res['db'];
      if (db is! Map) throw ApiException('Unexpected server response.', 500);
      _applyDb(db.cast<String, dynamic>());
      unawaited(_refreshComplaints());
    } on ApiException catch (e) {
      state = _copy(liveBusy: false, liveError: e.message);
    } catch (_) {
      state = _copy(liveBusy: false, liveError: 'Could not load your work data. Pull to retry.');
    }
  }

  /// Re-maps a fresh `db` snapshot into state (used after every action —
  /// the action endpoint returns the authoritative post-mutation snapshot).
  void _applyDb(Map<String, dynamic> db) {
    final snap = mapWorklogDb(db);
    state = ProtoState(
      phase: ProtoPhase.home,
      scenario: 'live',
      employee: snap.employee,
      entries: snap.entries,
      tasks: snap.tasks,
      projects: snap.projects,
      clientCategories: snap.clientCategories,
      clientSubcategories: snap.clientSubcategories,
      orgNames: snap.orgNames,
      selectedDateOffset: state.selectedDateOffset,
      complaints: state.complaints,
      activeBreak: snap.activeBreak,
      liveBusy: false,
    );
  }

  /// Applies an action response: fresh snapshot on success, error message on
  /// failure. Returns true when the action succeeded.
  bool _applyActionResult(Map<String, dynamic> res) {
    if (res['ok'] == true) {
      final db = res['db'];
      if (db is Map) _applyDb(db.cast<String, dynamic>());
      state = _copy(clearLiveError: true);
      return true;
    }
    state = _copy(liveError: res['message'] as String? ?? 'The action failed.');
    return false;
  }

  void _setLiveError(String message) => state = _copy(liveError: message);

  void clearLiveError() => state = _copy(clearLiveError: true);

  /* ---------------- demo auth scenarios ---------------- */

  /// Google button — routes to the chosen demo scenario (demo mode only).
  void signIn(String scenario) {
    if (state.isLive) return;
    switch (scenario) {
      case 'invite':
        _enterHome(MockData.clientSiteEmployee(), 'invite');
      case 'returning':
        _enterHome(MockData.inHouseEmployee(), 'returning');
      default: // 'new' → self-service onboarding
        state = const ProtoState(phase: ProtoPhase.onboarding, scenario: 'new');
    }
  }

  void _enterHome(Employee e, String scenario) {
    state = ProtoState(
      phase: ProtoPhase.home,
      scenario: scenario,
      employee: e,
      entries: MockData.seedEntries(e),
      tasks: List.of(MockData.tasks),
      complaints: MockData.seedComplaints(),
    );
  }

  /* ---------------- onboarding ---------------- */

  void setArrangement(WorkArrangement a) =>
      state = ProtoState(
        phase: ProtoPhase.onboarding,
        scenario: state.scenario,
        onboarding: {...state.onboarding, 'arrangement': a},
        employee: state.employee,
        entries: state.entries,
        tasks: state.tasks,
        projects: state.projects,
        clientCategories: state.clientCategories,
        clientSubcategories: state.clientSubcategories,
        orgNames: state.orgNames,
        selectedDateOffset: state.selectedDateOffset,
        complaints: state.complaints,
        activeBreak: state.activeBreak,
      );

  void setClient(String clientOrgId) =>
      state = ProtoState(
        phase: ProtoPhase.onboarding,
        scenario: state.scenario,
        onboarding: {...state.onboarding, 'clientOrgId': clientOrgId},
        employee: state.employee,
        entries: state.entries,
        tasks: state.tasks,
        projects: state.projects,
        clientCategories: state.clientCategories,
        clientSubcategories: state.clientSubcategories,
        orgNames: state.orgNames,
        selectedDateOffset: state.selectedDateOffset,
        complaints: state.complaints,
        activeBreak: state.activeBreak,
      );

  void completeOnboarding({
    required String name,
    required String jobTitle,
    required String department,
  }) {
    if (state.isLive) return; // live onboarding goes through SessionService
    final ob = state.onboarding;
    final arrangement = ob['arrangement'] as WorkArrangement? ?? WorkArrangement.inHouse;
    final clientOrgId = arrangement == WorkArrangement.clientSite
        ? ob['clientOrgId'] as String?
        : null;
    final e = Employee(
      id: 'emp-new-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'New Team Member' : name.trim(),
      jobTitle: jobTitle.trim().isEmpty ? 'Team Member' : jobTitle.trim(),
      department: department.trim(),
      employerOrgId: MockData.employer.id,
      clientOrgId: clientOrgId,
      workArrangement: arrangement,
      scenario: 'new',
    );
    _enterHome(e, 'new');
  }

  void signOut() => state = const ProtoState();

  /* ---------------- worklog ---------------- */

  void selectDateOffset(int offset) => state = _copy(selectedDateOffset: offset);

  /// Entries for a specific day offset relative to today (0 = today).
  List<WorkEntry> entriesForOffset(int offset) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    return [
      for (final e in state.entries)
        if (e.day.year == day.year && e.day.month == day.month && e.day.day == day.day) e,
    ];
  }

  /// Entries for the currently selected date.
  List<WorkEntry> entriesForSelectedDate() => entriesForOffset(state.selectedDateOffset);

  void addEntry(WorkEntry e) {
    if (state.isLive) {
      unawaited(_liveAddEntry(e));
      return;
    }
    state = _copy(entries: [...state.entries, e]);
  }

  void updateEntry(WorkEntry updated) {
    if (state.isLive) {
      unawaited(_liveUpdateEntry(updated));
      return;
    }
    state = _copy(
      entries: [for (final e in state.entries) e.id == updated.id ? updated : e],
    );
  }

  void deleteEntry(String id) {
    if (state.isLive) {
      unawaited(_liveVoidEntry(id));
      return;
    }
    state = _copy(entries: [for (final e in state.entries) if (e.id != id) e]);
  }

  void addBreak({
    required int startMin,
    required int endMin,
    DateTime? date,
    WorkLocation location = WorkLocation.office,
  }) {
    if (state.isLive) {
      _setLiveError('Past breaks cannot be added — the server records breaks in real time.');
      return;
    }
    final now = DateTime.now();
    addEntry(WorkEntry(
      id: 'we-${DateTime.now().millisecondsSinceEpoch}',
      kind: EntryKind.breakEntry,
      date: DateTime((date ?? now).year, (date ?? now).month, (date ?? now).day),
      startMin: startMin,
      endMin: endMin,
      location: location,
    ));
  }

  void updateTaskStatus(String taskId, TaskStatus status) {
    if (state.isLive) {
      unawaited(_liveUpdateTaskStatus(taskId, status));
      return;
    }
    state = _copy(
      tasks: [
        for (final t in state.tasks)
          t.id == taskId ? Task(id: t.id, projectId: t.projectId, title: t.title, description: t.description, status: status, subtasks: t.subtasks, progressNotes: t.progressNotes) : t,
      ],
    );
  }

  /// Adds a subtask to an existing task; returns the new subtask id.
  String addSubtask(String taskId, String title) {
    final id = _uuid();
    if (state.isLive) {
      unawaited(_liveAddSubtask(id, taskId, title));
      return id;
    }
    state = _copy(
      tasks: [
        for (final t in state.tasks)
          t.id == taskId
              ? Task(
                  id: t.id,
                  projectId: t.projectId,
                  title: t.title,
                  description: t.description,
                  status: t.status,
                  subtasks: [...t.subtasks, Subtask(id: id, title: title.trim())],
                  progressNotes: t.progressNotes,
                )
              : t,
      ],
    );
    return id;
  }

  void addProgressNote(String taskId, String note) {
    if (state.isLive) {
      unawaited(_liveAddProgressNote(taskId, note));
      return;
    }
    state = _copy(
      tasks: [
        for (final t in state.tasks)
          t.id == taskId
              ? Task(id: t.id, projectId: t.projectId, title: t.title, description: t.description, status: t.status, subtasks: t.subtasks, progressNotes: [...t.progressNotes, note])
              : t,
      ],
    );
  }

  /* ---------------- live break ---------------- */

  static const breakAllowanceMin = 60;

  bool get isOnBreak => state.activeBreak != null;

  void startBreak() {
    if (state.activeBreak != null) return;
    if (state.isLive) {
      unawaited(_liveStartBreak());
      return;
    }
    state = _copy(activeBreak: ActiveBreak(startedAt: DateTime.now()));
  }

  /// Ends the live break and records the actual elapsed duration. Returns the
  /// recorded duration in minutes, or null when no break was active.
  int? endBreak() {
    final active = state.activeBreak;
    if (active == null) return null;
    final now = DateTime.now();
    final elapsed = now.difference(active.startedAt).inMinutes.clamp(0, 24 * 60);
    if (state.isLive) {
      final id = active.id;
      if (id != null) unawaited(_liveEndBreak(id));
      return elapsed;
    }
    state = _copy(activeBreak: null);
    if (elapsed > 0) {
      final startMin = active.startedAt.hour * 60 + active.startedAt.minute;
      addBreak(
        startMin: startMin,
        endMin: (startMin + elapsed).clamp(0, 24 * 60 - 1),
        date: active.startedAt,
      );
    }
    return elapsed;
  }

  /* ---------------- complaints ---------------- */

  Complaint addComplaint({
    required String subject,
    required String description,
    List<ComplaintFile> files = const [],
  }) {
    if (state.isLive) {
      unawaited(_liveAddComplaint(subject, description, files));
      return Complaint(
        id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
        reference: '',
        subject: subject,
        status: ComplaintStatus.newComplaint,
        submittedAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        messages: const [],
      );
    }
    final now = DateTime.now();
    final maxNum = state.complaints.fold<int>(0, (m, c) {
      final n = int.tryParse(c.reference.replaceFirst('WT-', '')) ?? 0;
      return n > m ? n : m;
    });
    final complaint = Complaint(
      id: 'cp-${now.millisecondsSinceEpoch}',
      reference: 'WT-${(maxNum + 1).toString().padLeft(4, '0')}',
      subject: subject.trim(),
      status: ComplaintStatus.newComplaint,
      submittedAt: now,
      lastMessageAt: now,
      messages: [
        ComplaintMessage(
          id: 'cm-${now.millisecondsSinceEpoch}-0',
          senderType: 'staff',
          senderName: state.employee?.name ?? 'You',
          senderRole: 'Staff',
          body: description.trim(),
          createdAt: now,
          attachments: files,
        ),
      ],
    );
    state = _copy(complaints: [complaint, ...state.complaints]);
    return complaint;
  }

  /// Staff reply — moves Awaiting Staff back to In Progress like the backend.
  void replyToComplaint(String complaintId, String body, {List<ComplaintFile> files = const []}) {
    if (state.isLive) {
      unawaited(_liveReplyComplaint(complaintId, body, files));
      return;
    }
    final now = DateTime.now();
    state = _copy(
      complaints: [
        for (final c in state.complaints)
          if (c.id == complaintId)
            c.copyWith(
              status: c.status == ComplaintStatus.awaitingStaff ? ComplaintStatus.inProgress : c.status,
              lastMessageAt: now,
              messages: [
                ...c.messages,
                ComplaintMessage(
                  id: 'cm-${now.millisecondsSinceEpoch}-${c.messages.length}',
                  senderType: 'staff',
                  senderName: state.employee?.name ?? 'You',
                  senderRole: 'Staff',
                  body: body.trim(),
                  createdAt: now,
                  attachments: files,
                ),
              ],
            )
          else
            c,
      ],
    );
  }

  void markComplaintRead(String complaintId) {
    if (state.isLive) {
      unawaited(_liveMarkComplaintRead(complaintId));
      return;
    }
    state = _copy(
      complaints: [
        for (final c in state.complaints)
          if (c.id == complaintId) c.copyWith(unreadByStaff: false) else c,
      ],
    );
  }

  /* ---------------- live mutations ---------------- */

  static String _uuid() {
    final r = Random.secure();
    String hex(int n) => List.generate(n, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
  }

  /// Africa/Lagos wall-clock DateTime → ISO-8601 UTC instant the API expects.
  static String _isoUtc(DateTime lagosWall) =>
      DateTime.utc(lagosWall.year, lagosWall.month, lagosWall.day, lagosWall.hour, lagosWall.minute)
          .subtract(const Duration(hours: 1))
          .toIso8601String();

  static String _isoFromMin(DateTime day, int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    return _isoUtc(DateTime(day.year, day.month, day.day, clamped ~/ 60, clamped % 60));
  }

  // DB enum is office|home|unknown — client-site maps to 'unknown' (the
  // recorded-absence value); live_mapping renders it back as clientSite.
  static String _workLocationWire(WorkLocation l) => switch (l) {
        WorkLocation.home => 'home',
        WorkLocation.clientSite => 'unknown',
        WorkLocation.office => 'office',
      };

  Future<List<String>> _uploadEntryAttachments(WorkEntry e) async {
    final ids = <String>[];
    for (final a in e.attachments) {
      final path = a.path;
      if (path == null) continue; // already persisted server-side
      ids.add(await _api.uploadWorkEntryFile(path, a.fileName));
    }
    return ids;
  }

  Map<String, dynamic> _entryInput(WorkEntry e, List<String> attachmentIds) {
    final emp = state.employee;
    final isClient = emp?.workArrangement == WorkArrangement.clientSite;
    return {
      'employeeId': emp?.id ?? '',
      if (!isClient && e.taskId != null) 'taskId': e.taskId,
      if (!isClient && e.subtaskId != null) 'subtaskId': e.subtaskId,
      if (isClient && e.clientCategoryId != null) 'clientCategoryId': e.clientCategoryId,
      if (isClient && e.clientSubcategoryId != null) 'clientSubcategoryId': e.clientSubcategoryId,
      'description': e.description,
      'startAt': _isoFromMin(e.date, e.startMin),
      'endAt': _isoFromMin(e.date, e.endMin),
      'workLocation': _workLocationWire(e.location),
      if (e.evidenceLink != null && e.evidenceLink!.isNotEmpty) 'evidenceLink': e.evidenceLink,
      'isReportedOvertime': e.isOvertime,
      if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
    };
  }

  Future<void> _liveAddEntry(WorkEntry e) async {
    state = _copy(liveBusy: true, clearLiveError: true);
    try {
      final attachmentIds = await _uploadEntryAttachments(e);
      final res = await _api.postAction('addEntry', {
        'id': _uuid(),
        'input': _entryInput(e, attachmentIds),
      });
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not save the entry. Check your connection.');
    } finally {
      state = _copy(liveBusy: false);
    }
  }

  Future<void> _liveUpdateEntry(WorkEntry updated) async {
    if (updated.kind == EntryKind.breakEntry) {
      // Break corrections go through updateBreak, not the work-entry edit path.
      try {
        final res = await _api.postAction('updateBreak', {
          'breakId': updated.id,
          'startAt': _isoFromMin(updated.date, updated.startMin),
          'endAt': _isoFromMin(updated.date, updated.endMin),
        });
        _applyActionResult(res);
      } on ApiException catch (err) {
        _setLiveError(err.message);
      } catch (_) {
        _setLiveError('Could not update the break.');
      }
      return;
    }
    state = _copy(liveBusy: true, clearLiveError: true);
    try {
      final attachmentIds = await _uploadEntryAttachments(updated);
      final res = await _api.postAction('editEntry', {
        'entryId': updated.id,
        'input': _entryInput(updated, attachmentIds),
      });
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not update the entry.');
    } finally {
      state = _copy(liveBusy: false);
    }
  }

  Future<void> _liveVoidEntry(String id) async {
    try {
      final res = await _api.postAction('voidEntry', {'entryId': id});
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not delete the entry.');
    }
  }

  Future<void> _liveUpdateTaskStatus(String taskId, TaskStatus status) async {
    final statusWire = status.name; // ongoing|done|blocked|dropped
    try {
      final res = await _api.postAction('updateTaskStatus', {
        'taskId': taskId,
        'status': statusWire,
        if (status == TaskStatus.blocked) 'reason': 'Marked blocked from the mobile app',
        if (status == TaskStatus.dropped) 'reason': 'Dropped from the mobile app',
      });
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not update the task status.');
    }
  }

  Future<void> _liveAddSubtask(String id, String taskId, String title) async {
    try {
      final res = await _api.postAction('createSubtask', {
        'id': id,
        'taskId': taskId,
        'title': title.trim(),
      });
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not add the subtask.');
    }
  }

  Future<void> _liveAddProgressNote(String taskId, String note) async {
    try {
      final res = await _api.postAction('addProgressUpdate', {
        'id': _uuid(),
        'taskId': taskId,
        'body': note.trim(),
      });
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not save the progress note.');
    }
  }

  Future<void> _liveStartBreak() async {
    try {
      final res = await _api.postAction('startBreak', {'id': _uuid()});
      if (_applyActionResult(res)) {
        // Snapshot may lag the just-created break on some backends; ensure the
        // countdown card appears immediately.
        if (state.activeBreak == null) {
          state = _copy(activeBreak: ActiveBreak(startedAt: DateTime.now()));
        }
      }
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not start the break.');
    }
  }

  Future<void> _liveEndBreak(String breakId) async {
    try {
      final res = await _api.postAction('endBreak', {'breakId': breakId});
      _applyActionResult(res);
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not end the break.');
    }
  }

  Future<void> _refreshComplaints() async {
    try {
      final records = await _api.fetchComplaints();
      state = _copy(complaints: mapComplaints(records));
    } catch (_) {
      // Complaints are secondary — a failure here must not break the workspace.
    }
  }

  Future<void> _liveAddComplaint(
    String subject,
    String description,
    List<ComplaintFile> files,
  ) async {
    state = _copy(liveBusy: true, clearLiveError: true);
    try {
      final res = await _api.createComplaint(
        subject: subject.trim(),
        description: description.trim(),
        files: files,
      );
      if (res['ok'] == true) {
        state = _copy(clearLiveError: true);
        await _refreshComplaints();
      } else {
        _setLiveError(res['message'] as String? ?? 'Could not submit the complaint.');
      }
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not submit the complaint. Check your connection.');
    } finally {
      state = _copy(liveBusy: false);
    }
  }

  Future<void> _liveReplyComplaint(
    String complaintId,
    String body,
    List<ComplaintFile> files,
  ) async {
    try {
      final attachmentIds = <String>[];
      for (final f in files) {
        final path = f.path;
        if (path != null) {
          attachmentIds.add(await _api.uploadComplaintFile(complaintId, path, f.fileName));
        }
      }
      final res = await _api.complaintAction(
        complaintId,
        type: 'reply',
        body: body.trim(),
        attachmentIds: attachmentIds,
      );
      if (res['ok'] == true) {
        await _refreshComplaints();
      } else {
        _setLiveError(res['message'] as String? ?? 'Could not send the reply.');
      }
    } on ApiException catch (err) {
      _setLiveError(err.message);
    } catch (_) {
      _setLiveError('Could not send the reply.');
    }
  }

  Future<void> _liveMarkComplaintRead(String complaintId) async {
    // Optimistic clear, then reconcile with the server.
    state = _copy(
      complaints: [
        for (final c in state.complaints)
          if (c.id == complaintId) c.copyWith(unreadByStaff: false) else c,
      ],
    );
    try {
      await _api.complaintAction(complaintId, type: 'markRead');
      await _refreshComplaints();
    } catch (_) {/* read-marker is best-effort */}
  }

  /* ---------------- state helpers ---------------- */

  /// Lookup helpers used by screens — live data first, mock fallback.
  String projectName(String id) {
    for (final p in state.projects) {
      if (p.id == id) return p.name;
    }
    return MockData.projectName(id);
  }

  String taskTitle(String id) {
    for (final t in state.tasks) {
      if (t.id == id) return t.title;
    }
    return MockData.taskTitle(id);
  }

  String categoryName(String id) {
    for (final c in state.clientCategories) {
      if (c.id == id) return c.name;
    }
    return MockData.categoryName(id);
  }

  String subcategoryName(String id) {
    for (final s in state.clientSubcategories) {
      if (s.id == id) return s.name;
    }
    return MockData.subcategoryName(id);
  }

  String orgName(String id) => state.orgNames[id] ?? MockData.orgName(id);

  List<Project> get projects => state.isLive ? state.projects : MockData.projects;
  List<ClientCategory> get clientCategories =>
      state.isLive ? state.clientCategories : MockData.clientCategories;
  List<ClientSubcategory> get clientSubcategories =>
      state.isLive ? state.clientSubcategories : MockData.clientSubcategories;

  ProtoState _copy({
    List<WorkEntry>? entries,
    List<Task>? tasks,
    List<Complaint>? complaints,
    ActiveBreak? activeBreak,
    bool clearBreak = false,
    int? selectedDateOffset,
    List<Project>? projects,
    List<ClientCategory>? clientCategories,
    List<ClientSubcategory>? clientSubcategories,
    Map<String, String>? orgNames,
    String? liveError,
    bool clearLiveError = false,
    bool? liveBusy,
  }) =>
      ProtoState(
        phase: state.phase,
        scenario: state.scenario,
        employee: state.employee,
        onboarding: state.onboarding,
        entries: entries ?? state.entries,
        tasks: tasks ?? state.tasks,
        projects: projects ?? state.projects,
        clientCategories: clientCategories ?? state.clientCategories,
        clientSubcategories: clientSubcategories ?? state.clientSubcategories,
        orgNames: orgNames ?? state.orgNames,
        selectedDateOffset: selectedDateOffset ?? state.selectedDateOffset,
        complaints: complaints ?? state.complaints,
        activeBreak: clearBreak ? null : (activeBreak ?? state.activeBreak),
        liveError: clearLiveError ? null : (liveError ?? state.liveError),
        liveBusy: liveBusy ?? state.liveBusy,
      );
}

final protoStoreProvider = NotifierProvider<ProtoStore, ProtoState>(ProtoStore.new);
