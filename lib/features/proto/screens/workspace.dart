import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../mock_data.dart';
import '../proto_store.dart';
import 'auth_onboarding.dart' show fmtDur, fmtMin;

const _green = Color(0xFF27AE60);
const _azure = Color(0xFF2E86DE);

/// Bottom-nav shell: Home / My Work / Tasks / Profile.
class ProtoShell extends ConsumerStatefulWidget {
  const ProtoShell({super.key});
  @override
  ConsumerState<ProtoShell> createState() => _ProtoShellState();
}

class _ProtoShellState extends ConsumerState<ProtoShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const ProtoHomePage(),
      const ProtoMyWorkPage(),
      const ProtoTasksPage(),
      const ProtoProfilePage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: _green.withValues(alpha: .12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: _green), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: _green), label: 'My Work'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist, color: _green), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: _green), label: 'Profile'),
        ],
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

String _todayLabel() => DateTime.now().toString().split(' ').first; // demo date

class _Summary {
  static ({int work, int brk, int ot}) compute(List<WorkEntry> entries) {
    var work = 0, brk = 0, ot = 0;
    for (final e in entries) {
      if (e.kind == EntryKind.breakEntry) { brk += e.durationMin; continue; }
      if (e.isOvertime) { ot += e.durationMin; work += e.durationMin; }
      else { work += e.durationMin; }
    }
    return (work: work, brk: brk, ot: ot);
  }
}

class ProtoHomePage extends ConsumerWidget {
  const ProtoHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final entries = s.selectedDateOffset == 0 ? s.entries : const <WorkEntry>[];
    final sum = _Summary.compute(entries);
    final firstNames = e.name.split(' ').first;
    final workEntries = entries.where((x) => x.kind == EntryKind.work).toList();
    final current = workEntries.isNotEmpty ? workEntries.last : null;

    return Scaffold(
      appBar: AppBar(title: Text('$_greeting(), $firstNames'), actions: [
        Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(_todayLabel(), style: const TextStyle(fontSize: 12, color: Color(0xFF8B8B9A))))),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProtoLogWorkScreen())),
        backgroundColor: _green, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Log work'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Summary card
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            _Stat(label: 'Worked', value: fmtDur(sum.work), color: _green),
            _Stat(label: 'Overtime', value: fmtDur(sum.ot), color: _azure),
            _Stat(label: 'Breaks', value: fmtDur(sum.brk), color: const Color(0xFF8B8B9A)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: (sum.work / 480).clamp(0, 1), minHeight: 6, backgroundColor: const Color(0xFFF0EFF6), color: _green)),
          const SizedBox(height: 6),
          Text('${fmtDur(sum.work)} of 8h productive time', style: const TextStyle(fontSize: 11, color: Color(0xFF8B8B9A))),
        ]))),
        const SizedBox(height: 12),
        // Status strip
        Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: _green.withValues(alpha: .12), child: Icon(current != null ? Icons.play_arrow : Icons.pause, color: _green)),
          title: Text(current != null ? 'Last entry: ${MockData.taskTitle(current.taskId ?? '')} / ${MockData.categoryName(current.clientCategoryId ?? '')}' : 'No work logged yet today', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('${e.workArrangement == WorkArrangement.clientSite ? 'Client-site' : 'In-house'} · ${MockData.orgName(e.clientOrgId ?? e.employerOrgId)}', style: const TextStyle(fontSize: 12)),
        )),
        const SizedBox(height: 16),
        const Text('Today\'s activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        if (entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nothing logged yet — tap “Log work” to start.', style: TextStyle(color: Color(0xFF8B8B9A), fontSize: 13))),
        for (final en in entries.reversed) _EntryTile(entry: en, employee: e),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B8B9A))),
  ]));
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.employee});
  final WorkEntry entry; final Employee employee;

  @override
  Widget build(BuildContext context) {
    final isBreak = entry.kind == EntryKind.breakEntry;
    final title = isBreak
        ? 'Break'
        : entry.taskId != null
            ? '${MockData.projectName(_projectOf(entry.taskId!))} · ${MockData.taskTitle(entry.taskId!)}'
            : '${MockData.categoryName(entry.clientCategoryId ?? '')} · ${MockData.subcategoryName(entry.clientSubcategoryId ?? '')}';
    return Card(child: ListTile(
      dense: true,
      leading: Icon(isBreak ? Icons.coffee : Icons.work_outline, color: isBreak ? const Color(0xFF8B8B9A) : _green, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text('${fmtMin(entry.startMin)}–${fmtMin(entry.endMin)} · ${entry.location.name}${entry.isOvertime ? ' · OT' : ''}${entry.description.isNotEmpty ? ' · ${entry.description}' : ''}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8B8B9A)), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(fmtDur(entry.durationMin), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ));
  }

  String _projectOf(String taskId) => MockData.tasks.firstWhere((t) => t.id == taskId).projectId;
}

/// My Work — date-grouped activity list.
class ProtoMyWorkPage extends ConsumerWidget {
  const ProtoMyWorkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final entries = s.selectedDateOffset == 0 ? s.entries : const <WorkEntry>[];
    final sum = _Summary.compute(entries);
    return Scaffold(
      appBar: AppBar(title: const Text('My Work')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(protoStoreProvider.notifier).selectDateOffset(s.selectedDateOffset - 1)),
          Expanded(child: Center(child: Text(s.selectedDateOffset == 0 ? 'Today' : 'Day ${-s.selectedDateOffset}', style: const TextStyle(fontWeight: FontWeight.w700)))),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: s.selectedDateOffset >= 0 ? null : () => ref.read(protoStoreProvider.notifier).selectDateOffset(s.selectedDateOffset + 1)),
        ]),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Stat(label: 'Work', value: fmtDur(sum.work), color: _green),
          _Stat(label: 'Overtime', value: fmtDur(sum.ot), color: _azure),
          _Stat(label: 'Breaks', value: fmtDur(sum.brk), color: const Color(0xFF8B8B9A)),
        ]))),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No activity for this date.', style: TextStyle(color: Color(0xFF8B8B9A))))))
        else
          for (final en in entries.reversed) _EntryTile(entry: en, employee: e),
      ]),
    );
  }
}

/// Tasks — in-house hierarchy or client-site category overview.
class ProtoTasksPage extends ConsumerWidget {
  const ProtoTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    return Scaffold(
      appBar: AppBar(title: Text(isClient ? 'Work categories' : 'My tasks')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!isClient)
          for (final t in s.tasks)
            Card(child: ExpansionTile(
              leading: Icon(
                t.status == TaskStatus.done ? Icons.check_circle : t.status == TaskStatus.blocked ? Icons.block : Icons.radio_button_unchecked,
                color: t.status == TaskStatus.done ? _green : t.status == TaskStatus.blocked ? Colors.orange : const Color(0xFF8B8B9A), size: 20),
              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${MockData.projectName(t.projectId)} · ${t.subtasks.length} subtask(s) · ${t.progressNotes.length} update(s)', style: const TextStyle(fontSize: 11)),
              children: [
                for (final st in t.subtasks)
                  ListTile(dense: true, leading: const Icon(Icons.subdirectory_arrow_right, size: 16), title: Text(st.title, style: const TextStyle(fontSize: 13))),
                for (final n in t.progressNotes)
                  ListTile(dense: true, leading: const Icon(Icons.chat_bubble_outline, size: 16, color: _azure), title: Text(n, style: const TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Wrap(spacing: 6, children: [
                  for (final st in TaskStatus.values)
                    ChoiceChip(
                      label: Text(st.name, style: const TextStyle(fontSize: 11)),
                      selected: t.status == st,
                      onSelected: (_) => ref.read(protoStoreProvider.notifier).updateTaskStatus(t.id, st),
                    ),
                ])),
              ],
            ))
        else
          for (final c in MockData.clientCategories.where((c) => c.clientId == e.clientOrgId))
            Card(child: ListTile(
              leading: const Icon(Icons.category_outlined, color: _azure),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(MockData.clientSubcategories.where((s) => s.categoryId == c.id).map((s) => s.name).join(' · '), style: const TextStyle(fontSize: 11)),
            )),
      ]),
    );
  }
}

/// Profile — employee details + simulated sign-out.
class ProtoProfilePage extends ConsumerWidget {
  const ProtoProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B8B9A), fontSize: 13)),
        Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
      ]),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          CircleAvatar(radius: 34, backgroundColor: _green.withValues(alpha: .12), child: Text(e.name.split(' ').map((w) => w[0]).take(2).join(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _green))),
          const SizedBox(height: 10),
          Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('${e.jobTitle} · ${e.department}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B8B9A))),
          const SizedBox(height: 6),
          Chip(label: Text(e.workArrangement == WorkArrangement.clientSite ? 'Client-site' : 'In-house', style: const TextStyle(fontSize: 11)), backgroundColor: _azure.withValues(alpha: .1), side: BorderSide.none),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          row('Employer', MockData.orgName(e.employerOrgId)),
          if (e.clientOrgId != null) row('Client', MockData.orgName(e.clientOrgId!)),
          row('Scenario', s.scenario),
          row('Account', 'Prototype (mock sign-in)'),
        ]))),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(protoStoreProvider.notifier).signOut(),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out (demo)'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318), side: const BorderSide(color: Color(0xFFF0C4C4))),
        ),
      ]),
    );
  }
}

/// Work-logging form — branches on work arrangement.
class ProtoLogWorkScreen extends ConsumerStatefulWidget {
  const ProtoLogWorkScreen({super.key});
  @override
  ConsumerState<ProtoLogWorkScreen> createState() => _ProtoLogWorkScreenState();
}

class _ProtoLogWorkScreenState extends ConsumerState<ProtoLogWorkScreen> {
  String? _taskId;
  String? _subtaskId;
  String? _categoryId;
  String? _subcategoryId;
  final _desc = TextEditingController();
  WorkLocation _location = WorkLocation.office;
  bool _overtime = false;
  int _start = 9 * 60, _end = 10 * 60;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    return Scaffold(
      appBar: AppBar(title: const Text('Log work')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (isClient) ...[
          _ro('Client organisation', MockData.orgName(e.clientOrgId ?? '')),
          _pick('Work category', MockData.clientCategories.where((c) => c.clientId == e.clientOrgId).map((c) => (c.id, c.name)).toList(), _categoryId, (v) => setState(() { _categoryId = v; _subcategoryId = null; })),
          _pick('Work subcategory', MockData.clientSubcategories.where((x) => x.categoryId == _categoryId).map((x) => (x.id, x.name)).toList(), _subcategoryId, (v) => setState(() => _subcategoryId = v)),
        ] else ...[
          _pick('Project', MockData.projects.map((p) => (p.id, p.name)).toList(), _taskId == null ? null : MockData.tasks.firstWhere((t) => t.id == _taskId).projectId, (v) {}),
          _pick('Task', s.tasks.map((t) => (t.id, t.title)).toList(), _taskId, (v) => setState(() { _taskId = v; _subtaskId = null; })),
          if (_taskId != null) _pick('Subtask', MockData.tasks.firstWhere((t) => t.id == _taskId).subtasks.map((x) => (x.id, x.title)).toList(), _subtaskId, (v) => setState(() => _subtaskId = v)),
        ],
        TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(labelText: isClient ? 'Work performed *' : 'Work performed (optional)', hintText: 'Describe what you did')),
        const SizedBox(height: 12),
        _pick('Location', [
          (WorkLocation.office.name, 'Office'), (WorkLocation.home.name, 'Home'),
          if (isClient) (WorkLocation.clientSite.name, 'Client site'),
        ].map((x) => (x.$1, x.$2)).toList(), _location.name, (v) => setState(() => _location = WorkLocation.values.firstWhere((l) => l.name == v))),
        Row(children: [
          Expanded(child: _time('Start', _start, (v) => setState(() => _start = v))),
          const SizedBox(width: 12),
          Expanded(child: _time('End', _end, (v) => setState(() => _end = v))),
        ]),
        CheckboxListTile(value: _overtime, onChanged: (v) => setState(() => _overtime = v ?? false), title: const Text('Overtime', style: TextStyle(fontSize: 13)), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 13))),
        FilledButton(onPressed: _save, style: FilledButton.styleFrom(backgroundColor: _green, minimumSize: const Size.fromHeight(50)), child: const Text('Save entry')),
      ]),
    );
  }

  Widget _ro(String label, String value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B8B9A))), subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.lock_outline, size: 16));

  Widget _pick(String label, List<(String, String)> options, String? selected, void Function(String?) onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white),
      items: [for (final o in options) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    ),
  );

  Widget _time(String label, int min, void Function(int) onChanged) {
    final items = [for (var m = 0; m < 24 * 60; m += 30) DropdownMenuItem(value: m, child: Text(fmtMin(m)))];
    return DropdownButtonFormField<int>(initialValue: min, decoration: InputDecoration(labelText: label), items: items, onChanged: (v) => onChanged(v ?? min));
  }

  void _save() {
    final s = ref.read(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    setState(() => _error = null);
    if (isClient && (_categoryId == null || _subcategoryId == null)) { setState(() => _error = 'Select a category and subcategory.'); return; }
    if (isClient && _desc.text.trim().isEmpty) { setState(() => _error = 'Describe the work performed.'); return; }
    if (!isClient && _taskId == null) { setState(() => _error = 'Select a task.'); return; }
    if (_end <= _start) { setState(() => _error = 'End time must be after start time.'); return; }
    ref.read(protoStoreProvider.notifier).addEntry(WorkEntry(
      id: 'we-${DateTime.now().millisecondsSinceEpoch}',
      kind: EntryKind.work,
      startMin: _start, endMin: _end,
      taskId: isClient ? null : _taskId,
      subtaskId: isClient ? null : _subtaskId,
      clientCategoryId: isClient ? _categoryId : null,
      clientSubcategoryId: isClient ? _subcategoryId : null,
      description: _desc.text.trim(),
      location: _location,
      isOvertime: _overtime,
    ));
    Navigator.of(context).pop();
  }
}
