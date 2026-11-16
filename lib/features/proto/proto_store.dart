import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_data.dart';
import 'models.dart';

/// Prototype session + worklog store. Simulates auth, onboarding and all
/// worklog mutations locally — the shape mirrors what the real backend will
/// provide, so screens don't change when real APIs land.
class ProtoStore extends Notifier<ProtoState> {
  static const workStart = 9 * 60; // 09:00 Africa/Lagos
  static const workEnd = 17 * 60; // 17:00

  @override
  ProtoState build() => const ProtoState();

  /* ---------------- auth scenarios ---------------- */

  /// Google button — routes to the chosen demo scenario.
  void signIn(String scenario) {
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
    );
  }

  /* ---------------- onboarding ---------------- */

  void setArrangement(WorkArrangement a) =>
      state = ProtoState(
        phase: ProtoPhase.onboarding,
        scenario: state.scenario,
        onboarding: {...state.onboarding, 'arrangement': a},
      );

  void setClient(String clientOrgId) =>
      state = ProtoState(
        phase: ProtoPhase.onboarding,
        scenario: state.scenario,
        onboarding: {...state.onboarding, 'clientOrgId': clientOrgId},
        employee: state.employee,
        entries: state.entries,
        tasks: state.tasks,
        selectedDateOffset: state.selectedDateOffset,
      );

  void completeOnboarding({
    required String name,
    required String jobTitle,
    required String department,
  }) {
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

  void selectDateOffset(int offset) =>
      state = ProtoState(
        phase: state.phase,
        scenario: state.scenario,
        employee: state.employee,
        onboarding: state.onboarding,
        entries: state.entries,
        tasks: state.tasks,
        selectedDateOffset: offset,
      );

  /// Entries for the currently selected date (offset 0 = seeded "today").
  List<WorkEntry> entriesForSelectedDate() {
    if (state.selectedDateOffset != 0) return const [];
    return state.entries;
  }

  void addEntry(WorkEntry e) => state = _copy(entries: [...state.entries, e]);

  void updateEntry(WorkEntry updated) => state = _copy(
        entries: [
          for (final e in state.entries) e.id == updated.id ? updated : e,
        ],
      );

  void addBreak({required int startMin, required int endMin, WorkLocation location = WorkLocation.office}) {
    addEntry(WorkEntry(
      id: 'we-${DateTime.now().millisecondsSinceEpoch}',
      kind: EntryKind.breakEntry,
      startMin: startMin,
      endMin: endMin,
      location: location,
    ));
  }

  void updateTaskStatus(String taskId, TaskStatus status) {
    state = _copy(
      tasks: [
        for (final t in state.tasks)
          t.id == taskId ? Task(id: t.id, projectId: t.projectId, title: t.title, description: t.description, status: status, subtasks: t.subtasks, progressNotes: t.progressNotes) : t,
      ],
    );
  }

  void addProgressNote(String taskId, String note) {
    state = _copy(
      tasks: [
        for (final t in state.tasks)
          t.id == taskId
              ? Task(id: t.id, projectId: t.projectId, title: t.title, description: t.description, status: t.status, subtasks: t.subtasks, progressNotes: [...t.progressNotes, note])
              : t,
      ],
    );
  }

  ProtoState _copy({List<WorkEntry>? entries, List<Task>? tasks}) => ProtoState(
        phase: state.phase,
        scenario: state.scenario,
        employee: state.employee,
        onboarding: state.onboarding,
        entries: entries ?? state.entries,
        tasks: tasks ?? state.tasks,
        selectedDateOffset: state.selectedDateOffset,
      );
}

final protoStoreProvider = NotifierProvider<ProtoStore, ProtoState>(ProtoStore.new);
