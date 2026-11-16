import 'models.dart';

/// Prototype fixtures — small but realistic. Screens read these only through
/// ProtoStore; nothing hardcodes employee data per-screen.
class MockData {
  MockData._();

  static const employer = Org(id: 'org-employer', name: 'TechSpecialist Consult Limited', kind: 'employer');
  static const clients = [
    Org(id: 'org-bpp', name: 'BPP', kind: 'client'),
    Org(id: 'org-mac', name: 'MacArthur Foundation', kind: 'client'),
  ];

  static final projects = [
    Project(id: 'p-support', name: 'Client Support Portal', team: 'Service Desk'),
    Project(id: 'p-ops', name: 'Internal Operations', team: 'Operations'),
  ];

  static final tasks = [
    Task(
      id: 't-ticket-queue',
      projectId: 'p-support',
      title: 'Ticket queue triage',
      description: 'Review and prioritise incoming support tickets.',
      subtasks: [
        Subtask(id: 'st-review', title: 'Review new tickets'),
        Subtask(id: 'st-assign', title: 'Assign priorities'),
      ],
      progressNotes: ['Cleared 12 stale tickets from the queue.'],
    ),
    Task(
      id: 't-knowledge',
      projectId: 'p-support',
      title: 'Knowledge base refresh',
      description: 'Update help articles for the new portal release.',
      status: TaskStatus.blocked,
      subtasks: [Subtask(id: 'st-draft', title: 'Draft updated articles')],
    ),
    Task(
      id: 't-report',
      projectId: 'p-ops',
      title: 'Weekly ops report',
      description: 'Compile Monday ops summary for management.',
      subtasks: [Subtask(id: 'st-data', title: 'Collect metrics')],
    ),
  ];

  static final clientCategories = [
    ClientCategory(id: 'cc-incident', name: 'Incident Management', clientId: 'org-bpp'),
    ClientCategory(id: 'cc-change', name: 'Change Management', clientId: 'org-bpp'),
    ClientCategory(id: 'cc-field', name: 'Field Engineering', clientId: 'org-mac'),
  ];

  static final clientSubcategories = [
    ClientSubcategory(id: 'cs-p1', categoryId: 'cc-incident', name: 'Priority 1 response'),
    ClientSubcategory(id: 'cs-p2', categoryId: 'cc-incident', name: 'Priority 2 response'),
    ClientSubcategory(id: 'cs-chg', categoryId: 'cc-change', name: 'Standard change'),
    ClientSubcategory(id: 'cs-field', categoryId: 'cc-field', name: 'Site visit'),
  ];

  /// In-house employee — "existing employee" scenario, mid-morning Monday.
  static Employee inHouseEmployee() => const Employee(
        id: 'emp-inhouse',
        name: 'Amaka Okafor',
        jobTitle: 'Support Engineer',
        department: 'Client Services',
        employerOrgId: 'org-employer',
        scenario: 'returning',
      );

  /// Client-site employee — "invited employee" scenario.
  static Employee clientSiteEmployee() => const Employee(
        id: 'emp-client',
        name: 'Chidi Eze',
        jobTitle: 'Field Engineer',
        department: 'Deployment',
        employerOrgId: 'org-employer',
        clientOrgId: 'org-bpp',
        workArrangement: WorkArrangement.clientSite,
        scenario: 'invite',
      );

  /// Seeded entries for "today" (a Monday). 9:00 = 540.
  static List<WorkEntry> seedEntries(Employee e) {
    if (e.workArrangement == WorkArrangement.clientSite) {
      return [
        WorkEntry(
          id: 'we-1', kind: EntryKind.work, startMin: 540, endMin: 660,
          clientCategoryId: 'cc-incident', clientSubcategoryId: 'cs-p1',
          description: 'Responded to P1 outage at client site', location: WorkLocation.clientSite,
        ),
        WorkEntry(id: 'we-2', kind: EntryKind.breakEntry, startMin: 660, endMin: 690, location: WorkLocation.clientSite),
        WorkEntry(
          id: 'we-3', kind: EntryKind.work, startMin: 690, endMin: 780, isOvertime: true,
          clientCategoryId: 'cc-change', clientSubcategoryId: 'cs-chg',
          description: 'Completed standard change request', location: WorkLocation.clientSite,
        ),
      ];
    }
    return [
      WorkEntry(
        id: 'we-1', kind: EntryKind.work, startMin: 540, endMin: 720,
        taskId: 't-ticket-queue', subtaskId: 'st-review',
        description: 'Triaged overnight ticket backlog', location: WorkLocation.office,
      ),
      WorkEntry(id: 'we-2', kind: EntryKind.breakEntry, startMin: 720, endMin: 750, location: WorkLocation.office),
      WorkEntry(
        id: 'we-3', kind: EntryKind.work, startMin: 750, endMin: 900,
        taskId: 't-report', subtaskId: 'st-data',
        description: 'Pulled weekly ops metrics', location: WorkLocation.office,
      ),
    ];
  }

  static String orgName(String id) =>
      [employer, ...clients].firstWhere((o) => o.id == id, orElse: () => employer).name;

  static String projectName(String id) =>
      projects.firstWhere((p) => p.id == id, orElse: () => projects.first).name;

  static String taskTitle(String id) =>
      tasks.firstWhere((t) => t.id == id, orElse: () => tasks.first).title;

  static String categoryName(String id) =>
      clientCategories.firstWhere((c) => c.id == id, orElse: () => clientCategories.first).name;

  static String subcategoryName(String id) =>
      clientSubcategories.firstWhere((s) => s.id == id, orElse: () => clientSubcategories.first).name;
}
