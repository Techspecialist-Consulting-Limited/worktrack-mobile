import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models.dart';
import '../mock_data.dart';
import '../proto_store.dart';
import '../widgets/proto_fields.dart';
import 'complaints.dart' show fmtBytes;
import 'workspace.dart' show formatLongDate;

const _allowedAttachmentExtensions = {
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'txt',
  'jpg', 'jpeg', 'png', 'webp',
};
const _maxAttachmentBytes = 10 * 1024 * 1024;

/// Log Work — schedule-driven time selection, arrangement-specific details.
class ProtoLogWorkScreen extends ConsumerStatefulWidget {
  const ProtoLogWorkScreen({super.key, this.editing});
  final WorkEntry? editing;
  @override
  ConsumerState<ProtoLogWorkScreen> createState() => _ProtoLogWorkScreenState();
}

class _ProtoLogWorkScreenState extends ConsumerState<ProtoLogWorkScreen> {
  // Standard schedule — Africa/Lagos, Mon–Fri 09:00–17:00, 15-minute steps.
  static const _dayStart = 9 * 60;
  static const _dayEnd = 17 * 60;
  static const _step = 15;

  String? _projectId;
  String? _activity; // 'task:<id>' | 'sub:<taskId>:<subId>'
  String? _categoryId;
  String? _subcategoryId;
  final _desc = TextEditingController();
  WorkLocation _location = WorkLocation.office;
  bool _overtime = false;
  late int _start;
  late int _end;
  late DateTime _date;
  bool _saving = false;
  String? _error;
  List<AttachmentItem> _attachments = [];
  final _link = TextEditingController();
  bool _showLink = false;
  bool _pickingFiles = false;

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _date = editing.day;
      _start = editing.startMin;
      _end = editing.endMin;
      _overtime = editing.isOvertime;
      _location = editing.location;
      _desc.text = editing.description;
      _attachments = List.of(editing.attachments);
      if (editing.evidenceLink != null) {
        _link.text = editing.evidenceLink!;
        _showLink = true;
      }
      if (editing.kind == EntryKind.work) {
        if (editing.clientCategoryId != null) {
          _categoryId = editing.clientCategoryId;
          _subcategoryId = editing.clientSubcategoryId;
        } else if (editing.taskId != null) {
          final task = ref.read(protoStoreProvider).tasks.where((t) => t.id == editing.taskId).firstOrNull;
          if (task != null) {
            _projectId = task.projectId;
            _activity = editing.subtaskId != null ? 'sub:${editing.taskId}:${editing.subtaskId}' : 'task:${editing.taskId}';
          }
        }
      }
      return;
    }
    _date = DateTime.now();
    _applyDefaultTimes();
  }

  @override
  void dispose() {
    _desc.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    if (_pickingFiles) return;
    setState(() => _pickingFiles = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedAttachmentExtensions.toList(),
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _error = null;
        for (final f in picked) {
          final ext = f.extension ?? f.name.split('.').last.toLowerCase();
          final size = f.lengthSync() ?? 0;
          if (!_allowedAttachmentExtensions.contains(ext)) {
            _error = '"${f.name}" has an unsupported file type.';
            continue;
          }
          if (size > _maxAttachmentBytes) {
            _error = '"${f.name}" is larger than 10 MB.';
            continue;
          }
          _attachments.add(AttachmentItem(
            id: 'att-${DateTime.now().millisecondsSinceEpoch}-${_attachments.length}',
            fileName: f.name,
            sizeBytes: size,
            addedAt: DateTime.now(),
            path: f.path,
          ));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the file picker.');
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  int get _rangeEnd => _overtime ? 21 * 60 : _dayEnd;

  /// First non-overlapping hourly interval for the selected date.
  void _applyDefaultTimes() {
    int start, end;
    if (_isToday) {
      final h = DateTime.now().hour;
      if (h >= 9 && h <= 15) {
        start = h * 60;
        end = start + 60;
      } else if (h == 16) {
        start = 16 * 60;
        end = _dayEnd;
      } else {
        start = 10 * 60;
        end = 11 * 60;
      }
    } else {
      start = _dayStart;
      end = _dayStart + 60;
    }
    // Prefer the next available interval if this one is already logged.
    final selectedDay = DateTime(_date.year, _date.month, _date.day);
    final busy = ref.read(protoStoreProvider).entries
        .where((en) => en.kind == EntryKind.work && en.day.year == selectedDay.year && en.day.month == selectedDay.month && en.day.day == selectedDay.day)
        .toList();
    var guard = 0;
    while (start + 60 <= _dayEnd && busy.any((en) => en.startMin < start + 60 && en.endMin > start) && guard++ < 12) {
      start += 60;
      end = start + 60;
    }
    _start = start;
    _end = end;
  }

  List<ProtoOption<int>> get _startOptions {
    final first = _overtime ? 17 * 60 : _dayStart;
    return [
      for (var m = first; m + _step <= _rangeEnd; m += _step) ProtoOption(value: m, label: fmtTime12(m)),
    ];
  }

  List<ProtoOption<int>> get _endOptions => [
        for (var m = _start + _step; m <= _rangeEnd; m += _step) ProtoOption(value: m, label: fmtTime12(m)),
      ];

  void _setStart(int v) => setState(() {
        _start = v;
        if (_end <= _start || _end > _rangeEnd) _end = (_start + 60).clamp(_start + _step, _rangeEnd);
      });

  void _setEnd(int v) => setState(() => _end = v);

  void _setOvertime(bool v) => setState(() {
        _overtime = v;
        _start = v ? 17 * 60 : 10 * 60;
        _end = _start + 60;
      });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
        _applyDefaultTimes();
      });
    }
  }

  List<Task> _projectTasks() {
    final s = ref.read(protoStoreProvider);
    return s.tasks.where((t) => t.projectId == _projectId).toList();
  }

  List<ProtoOption<String>> _activityOptionsFor(List<Task> projTasks) => [
        for (final t in projTasks) ProtoOption(value: 'task:${t.id}', label: t.title, subtitle: 'Task'),
        for (final t in projTasks)
          for (final st in t.subtasks) ProtoOption(value: 'sub:${t.id}:${st.id}', label: st.title, subtitle: t.title),
        const ProtoOption(value: '__add__', label: 'Add new subtask', subtitle: 'Create under a task in this project'),
      ];

  Future<void> _addSubtask() async {
    final tasks = _projectTasks();
    if (tasks.isEmpty) return;
    String taskId = tasks.first.id;
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add subtask', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tasks.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: taskId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: [for (final t in tasks) DropdownMenuItem(value: t.id, child: Text(t.title, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setD(() => taskId = v ?? taskId),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Subtask name', hintText: 'e.g. Review pending tickets'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop('$taskId|${nameCtrl.text.trim()}');
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (result == null || !mounted) return;
    final parts = result.split('|');
    final newId = ref.read(protoStoreProvider.notifier).addSubtask(parts[0], parts[1]);
    setState(() => _activity = 'sub:${parts[0]}:$newId');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    final categories = (s.isLive ? s.clientCategories : MockData.clientCategories)
        .where((c) => c.clientId == e.clientOrgId)
        .toList();
    final subcategories = (s.isLive ? s.clientSubcategories : MockData.clientSubcategories)
        .where((x) => x.categoryId == _categoryId)
        .toList();
    final projects = s.isLive ? s.projects : MockData.projects;

    return Scaffold(
      appBar: AppBar(title: Text(widget.editing != null ? 'Edit entry' : 'Log Work')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Date & working-hours card — tappable for date selection
          Material(
            color: const Color(0xFFF0ECFF),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_month_rounded, size: 19, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatLongDate(_date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          const Text('Standard work hours: 9:00 AM – 5:00 PM', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
          if (s.activeBreak != null && _isToday) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3D9A4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.coffee_rounded, size: 17, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('You are on a break — end it from Home before logging work.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A5A00), height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Time selection — 15-minute granularity, end constrained by start
          const ProtoSectionLabel('Time'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProtoSelectField<int>(
                  label: 'Start time',
                  leadingIcon: Icons.schedule_rounded,
                  options: _startOptions,
                  selected: _start,
                  onChanged: _setStart,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 36, left: 8, right: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textMuted),
              ),
              Expanded(
                child: ProtoSelectField<int>(
                  label: 'End time',
                  leadingIcon: Icons.schedule_rounded,
                  options: _endOptions,
                  selected: _end,
                  onChanged: _setEnd,
                ),
              ),
            ],
          ),
          if (_overtime)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 2),
              child: Text('Overtime hours · outside 9:00 AM – 5:00 PM', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 24),

          // Work details — arrangement-specific, never mixed
          ProtoSectionLabel(isClient ? 'Work details' : 'Task details'),
          if (isClient) ...[
            _ReadOnlyField(label: 'Client organisation', icon: Icons.business_rounded, value: _orgName(s, e.clientOrgId ?? '')),
            const SizedBox(height: 14),
            ProtoSelectField<String>(
              label: 'Work category',
              leadingIcon: Icons.category_outlined,
              placeholder: 'Select work category',
              searchable: true,
              options: [for (final c in categories) ProtoOption(value: c.id, label: c.name)],
              selected: _categoryId,
              onChanged: (v) => setState(() {
                _categoryId = v;
                _subcategoryId = null;
              }),
            ),
            const SizedBox(height: 14),
            ProtoSelectField<String>(
              label: 'Work subcategory',
              leadingIcon: Icons.subdirectory_arrow_right_rounded,
              placeholder: 'Select work subcategory',
              enabled: _categoryId != null,
              options: [for (final x in subcategories) ProtoOption(value: x.id, label: x.name)],
              selected: _subcategoryId,
              onChanged: (v) => setState(() => _subcategoryId = v),
            ),
            const SizedBox(height: 14),
            _DescriptionField(
              controller: _desc,
              label: 'Work performed',
              required: true,
              hint: 'Describe the work you performed during this period...',
            ),
          ] else ...[
            ProtoSelectField<String>(
              label: 'Project',
              leadingIcon: Icons.folder_outlined,
              placeholder: 'Select a project',
              options: [for (final p in projects) ProtoOption(value: p.id, label: p.name, subtitle: p.team)],
              selected: _projectId,
              onChanged: (v) => setState(() {
                _projectId = v;
                _activity = null;
              }),
            ),
            const SizedBox(height: 14),
            ProtoSelectField<String>(
              label: 'Activity / subtask',
              leadingIcon: Icons.assignment_outlined,
              placeholder: 'Select an activity or subtask',
              enabled: _projectId != null,
              searchable: true,
              options: _activityOptionsFor(_projectTasks()),
              selected: _activity,
                  onChanged: (v) {
                    if (v == '__add__') {
                      _addSubtask();
                    } else {
                      setState(() => _activity = v);
                    }
                  },
            ),
            const SizedBox(height: 14),
            _DescriptionField(
              controller: _desc,
              label: 'What did you work on during this time?',
              required: false,
              hint: 'Add details about the work you did (optional)',
            ),
          ],
          const SizedBox(height: 24),

          // Work location — selectable cards, not a dropdown
          const ProtoSectionLabel('Work location'),
          Row(
            children: [
              _LocationCard(
                icon: Icons.business_rounded,
                label: 'Office',
                selected: _location == WorkLocation.office,
                onTap: () => setState(() => _location = WorkLocation.office),
              ),
              const SizedBox(width: 10),
              _LocationCard(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: _location == WorkLocation.home,
                onTap: () => setState(() => _location = WorkLocation.home),
              ),
              if (isClient) ...[
                const SizedBox(width: 10),
                _LocationCard(
                  icon: Icons.location_on_outlined,
                  label: 'Client site',
                  selected: _location == WorkLocation.clientSite,
                  onTap: () => setState(() => _location = WorkLocation.clientSite),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Evidence & attachments — compact two-button row like the web form
          const ProtoSectionLabel('Evidence & attachments'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickingFiles ? null : _pickAttachments,
                  icon: _pickingFiles
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.attach_file_rounded, size: 17),
                  label: const Text('Documents / Images'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showLink = !_showLink),
                  icon: const Icon(Icons.link_rounded, size: 17),
                  label: Text(_showLink ? 'Hide link' : 'Add link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: _showLink ? AppColors.primary : AppColors.textSecondary,
                    backgroundColor: _showLink ? AppColors.lavender : Colors.white,
                    side: BorderSide(color: _showLink ? AppColors.primary : AppColors.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Documents or images up to 10 MB each.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _attachments.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Icon(_attachments[i].isImage ? Icons.image_outlined : Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_attachments[i].fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text(fmtBytes(_attachments[i].sizeBytes), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _attachments.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ],
          if (_showLink) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Evidence link',
                hintText: 'https://',
                prefixIcon: Icon(Icons.link_rounded, size: 18),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Overtime
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: _overtime,
              onChanged: _saving ? null : _setOvertime,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              activeThumbColor: AppColors.primary,
              title: const Text('Overtime', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Only for work outside 9:00 AM–5:00 PM, Monday–Friday', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: (_saving || (s.activeBreak != null && _isToday)) ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_saving ? 'Saving…' : 'Save entry'),
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String? taskId, String? subtaskId}) _parseActivity() {
    final a = _activity;
    if (a == null) return (taskId: null, subtaskId: null);
    final parts = a.split(':');
    if (parts.first == 'task') return (taskId: parts[1], subtaskId: null);
    return (taskId: parts[1], subtaskId: parts.length > 2 ? parts[2] : null);
  }

  void _save() {
    final s = ref.read(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    setState(() => _error = null);

    if (s.activeBreak != null && _isToday) {
      setState(() => _error = 'End your break before logging work.');
      return;
    }

    String? error;
    String? taskId;
    String? subtaskId;
    if (isClient) {
      if (_categoryId == null || _subcategoryId == null) {
        error = 'Select a work category and subcategory.';
      } else if (_desc.text.trim().isEmpty) {
        error = 'Describe the work performed.';
      }
    } else {
      if (_activity == null) {
        error = 'Select a project and an activity or subtask.';
      } else {
        final p = _parseActivity();
        taskId = p.taskId;
        subtaskId = p.subtaskId;
      }
    }
    if (error == null && _end <= _start) error = 'End time must be after start time.';
    if (error == null) {
      final day = DateTime(_date.year, _date.month, _date.day);
      final overlaps = s.entries.any((en) =>
          en.kind == EntryKind.work &&
          en.id != widget.editing?.id &&
          en.day.year == day.year &&
          en.day.month == day.month &&
          en.day.day == day.day &&
          en.startMin < _end &&
          en.endMin > _start);
      if (overlaps) error = 'This time overlaps an existing work entry.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    // Simulated persistence delay.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final date = DateTime(_date.year, _date.month, _date.day);
      final editing = widget.editing;
      if (editing != null) {
        ref.read(protoStoreProvider.notifier).updateEntry(editing.copyWith(
              date: date,
              startMin: _start,
              endMin: _end,
              taskId: isClient ? null : taskId,
              subtaskId: isClient ? null : subtaskId,
              clientCategoryId: isClient ? _categoryId : null,
              clientSubcategoryId: isClient ? _subcategoryId : null,
              description: _desc.text.trim(),
              location: _location,
              isOvertime: _overtime,
              attachments: _attachments,
              evidenceLink: _link.text.trim().isEmpty ? null : _link.text.trim(),
              clearEvidenceLink: _link.text.trim().isEmpty,
            ));
      } else {
        ref.read(protoStoreProvider.notifier).addEntry(WorkEntry(
              id: 'we-${DateTime.now().millisecondsSinceEpoch}',
              kind: EntryKind.work,
              date: date,
              startMin: _start,
              endMin: _end,
              taskId: isClient ? null : taskId,
              subtaskId: isClient ? null : subtaskId,
              clientCategoryId: isClient ? _categoryId : null,
              clientSubcategoryId: isClient ? _subcategoryId : null,
              description: _desc.text.trim(),
              location: _location,
              isOvertime: _overtime,
              attachments: _attachments,
              evidenceLink: _link.text.trim().isEmpty ? null : _link.text.trim(),
            ));
      }
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(editing != null ? 'Entry updated' : 'Work entry saved'), behavior: SnackBarBehavior.floating));
    });
  }
}

/// Read-only organisation field (client-site employees).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.icon, required this.value});
  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

/// Multiline work-performed input — ~115px, 500-char counter.
class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, required this.label, required this.required, required this.hint});
  final TextEditingController controller;
  final String label;
  final bool required;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (required) const Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
            ],
          ),
        ),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            counterStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

/// Selectable location card — lavender selected state, check indicator.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: Material(
        color: selected ? AppColors.lavender : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: 3),
                  const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _orgName(ProtoState s, String id) => s.orgNames[id] ?? MockData.orgName(id);
