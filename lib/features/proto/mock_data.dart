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

  /// In-house employee — "existing employee" scenario.
  static Employee inHouseEmployee() => const Employee(
        id: 'emp-inhouse',
        name: 'Daniel',
        jobTitle: 'Software Engineer',
        department: 'Engineering',
        employerOrgId: 'org-employer',
        scenario: 'returning',
      );

  /// Client-site employee — "invited employee" scenario.
  static Employee clientSiteEmployee() => const Employee(
        id: 'emp-client',
        name: 'Michael',
        jobTitle: 'Field Engineer',
        department: 'Deployment',
        employerOrgId: 'org-employer',
        clientOrgId: 'org-mac',
        workArrangement: WorkArrangement.clientSite,
        scenario: 'invite',
      );

  /// Seeded entries across recent days. 9:00 = 540, 17:00 = 1020.
  /// Overtime only occurs outside 09:00–17:00 Mon–Fri (or weekends); all
  /// overtime shown here is after 17:00 and is part of productive work time.
  static List<WorkEntry> seedEntries(Employee e) {
    final now = DateTime.now();
    DateTime d(int daysAgo) => DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
    if (e.workArrangement == WorkArrangement.clientSite) {
      return [
        WorkEntry(
          id: 'we-c1', kind: EntryKind.work, date: d(0), startMin: 540, endMin: 660,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'Completed scheduled site inspection at field office', location: WorkLocation.clientSite,
        ),
        WorkEntry(id: 'we-c2', kind: EntryKind.breakEntry, date: d(0), startMin: 660, endMin: 690, location: WorkLocation.clientSite),
        WorkEntry(
          id: 'we-c3', kind: EntryKind.work, date: d(0), startMin: 690, endMin: 900,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'Documented equipment maintenance findings', location: WorkLocation.clientSite,
        ),
        WorkEntry(
          id: 'we-c4', kind: EntryKind.work, date: d(0), startMin: 1020, endMin: 1080, isOvertime: true,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'After-hours review of site survey data', location: WorkLocation.clientSite,
        ),
        WorkEntry(
          id: 'we-c5', kind: EntryKind.work, date: d(1), startMin: 540, endMin: 780,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'Prepared deployment checklist and site materials', location: WorkLocation.clientSite,
        ),
        WorkEntry(id: 'we-c6', kind: EntryKind.breakEntry, date: d(1), startMin: 780, endMin: 810, location: WorkLocation.clientSite),
        WorkEntry(
          id: 'we-c7', kind: EntryKind.work, date: d(1), startMin: 810, endMin: 1020,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'On-site configuration and verification', location: WorkLocation.clientSite,
        ),
        WorkEntry(
          id: 'we-c8', kind: EntryKind.work, date: d(3), startMin: 600, endMin: 840,
          clientCategoryId: 'cc-field', clientSubcategoryId: 'cs-field',
          description: 'Client follow-up and incident documentation', location: WorkLocation.clientSite,
        ),
      ];
    }
    return [
      WorkEntry(
        id: 'we-1', kind: EntryKind.work, date: d(0), startMin: 540, endMin: 720,
        taskId: 't-ticket-queue', subtaskId: 'st-review',
        description: 'Triaged overnight ticket backlog', location: WorkLocation.office,
      ),
      WorkEntry(id: 'we-2', kind: EntryKind.breakEntry, date: d(0), startMin: 720, endMin: 750, location: WorkLocation.office),
      WorkEntry(
        id: 'we-3', kind: EntryKind.work, date: d(0), startMin: 750, endMin: 960,
        taskId: 't-report', subtaskId: 'st-data',
        description: 'Compiled weekly operations metrics', location: WorkLocation.office,
        attachments: const [
          AttachmentItem(id: 'att-1', fileName: 'ops-metrics-week46.xlsx', sizeBytes: 184320),
          AttachmentItem(id: 'att-2', fileName: 'dashboard-screenshot.png', sizeBytes: 96210),
        ],
      ),
      WorkEntry(
        id: 'we-4', kind: EntryKind.work, date: d(0), startMin: 1020, endMin: 1080, isOvertime: true,
        taskId: 't-ticket-queue', subtaskId: 'st-assign',
        description: 'After-hours escalation and priority reassignment', location: WorkLocation.office,
      ),
      WorkEntry(
        id: 'we-5', kind: EntryKind.work, date: d(1), startMin: 540, endMin: 780,
        taskId: 't-knowledge', subtaskId: 'st-draft',
        description: 'Updated portal help articles and screenshots', location: WorkLocation.office,
      ),
      WorkEntry(id: 'we-6', kind: EntryKind.breakEntry, date: d(1), startMin: 780, endMin: 810, location: WorkLocation.office),
      WorkEntry(
        id: 'we-7', kind: EntryKind.work, date: d(1), startMin: 810, endMin: 990,
        taskId: 't-ticket-queue', subtaskId: 'st-assign',
        description: 'Resolved priority queue and coordinated handoff', location: WorkLocation.office,
      ),
      WorkEntry(
        id: 'we-8', kind: EntryKind.work, date: d(3), startMin: 600, endMin: 900,
        taskId: 't-report', subtaskId: 'st-data',
        description: 'Prepared data extracts for operations review', location: WorkLocation.home,
      ),
    ];
  }

  /// Seeded complaints — mirrors the web admin workflow so staff can see
  /// status changes, admin replies and the unread badge in the prototype.
  static List<Complaint> seedComplaints() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);
    return [
      Complaint(
        id: 'cp-1',
        reference: 'WT-0003',
        subject: 'Printer on 3rd floor offline',
        status: ComplaintStatus.awaitingStaff,
        submittedAt: ago(const Duration(days: 1, hours: 3)),
        lastMessageAt: ago(const Duration(hours: 5)),
        unreadByStaff: true,
        messages: [
          ComplaintMessage(
            id: 'cm-1a',
            senderType: 'staff',
            senderName: 'Daniel',
            senderRole: 'Staff',
            body: 'The HP LaserJet on the 3rd floor has been offline since Monday. Several people have reported it and IT has not responded to the ticket I raised.',
            createdAt: ago(const Duration(days: 1, hours: 3)),
            attachments: const [ComplaintFile(id: 'cf-1', fileName: 'printer-error.png', sizeBytes: 148220)],
          ),
          ComplaintMessage(
            id: 'cm-1b',
            senderType: 'management',
            senderName: 'WorkTrack Admin',
            senderRole: 'Admin',
            body: 'Thanks for flagging this. Could you confirm the printer asset tag (usually on the front label) and whether the error light is solid or blinking? We have raised it with facilities.',
            createdAt: ago(const Duration(hours: 5)),
          ),
        ],
      ),
      Complaint(
        id: 'cp-2',
        reference: 'WT-0002',
        subject: 'October payslip deduction query',
        status: ComplaintStatus.resolved,
        submittedAt: ago(const Duration(days: 6)),
        lastMessageAt: ago(const Duration(days: 4)),
        messages: [
          ComplaintMessage(
            id: 'cm-2a',
            senderType: 'staff',
            senderName: 'Daniel',
            senderRole: 'Staff',
            body: 'My October payslip shows a deduction I do not recognise. Can someone explain what it is for?',
            createdAt: ago(const Duration(days: 6)),
          ),
          ComplaintMessage(
            id: 'cm-2b',
            senderType: 'management',
            senderName: 'WorkTrack Admin',
            senderRole: 'Admin',
            body: 'The deduction is the staff canteen meal-plan adjustment agreed in September. Payroll has added a note to your next payslip explaining it. Resolving this complaint — reply here if anything still looks wrong.',
            createdAt: ago(const Duration(days: 4)),
          ),
        ],
      ),
      Complaint(
        id: 'cp-3',
        reference: 'WT-0001',
        subject: 'Meeting room double-booking',
        status: ComplaintStatus.inProgress,
        submittedAt: ago(const Duration(days: 2)),
        lastMessageAt: ago(const Duration(days: 2)),
        messages: [
          ComplaintMessage(
            id: 'cm-3a',
            senderType: 'staff',
            senderName: 'Daniel',
            senderRole: 'Staff',
            body: 'Boardroom B was double-booked for Thursday\'s planning session — two teams showed up. The calendar invite system seems to allow overlapping bookings.',
            createdAt: ago(const Duration(days: 2)),
          ),
        ],
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
