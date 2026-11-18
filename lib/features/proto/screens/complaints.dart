import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../models.dart';
import '../proto_store.dart';

const _allowedExtensions = {
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'txt',
  'jpg', 'jpeg', 'png', 'webp',
};
const _maxFileBytes = 10 * 1024 * 1024;

String complaintStatusLabel(ComplaintStatus s) => switch (s) {
      ComplaintStatus.newComplaint => 'New',
      ComplaintStatus.inProgress => 'In Progress',
      ComplaintStatus.awaitingStaff => 'Awaiting Staff',
      ComplaintStatus.resolved => 'Resolved',
      ComplaintStatus.reopened => 'Reopened',
    };

Color complaintStatusColor(ComplaintStatus s) => switch (s) {
      ComplaintStatus.newComplaint => const Color(0xFF4A3FB8),
      ComplaintStatus.inProgress => const Color(0xFF8A5A00),
      ComplaintStatus.awaitingStaff => const Color(0xFFB43A3A),
      ComplaintStatus.resolved => const Color(0xFF177A3D),
      ComplaintStatus.reopened => const Color(0xFF7A2FC4),
    };

Color complaintStatusBg(ComplaintStatus s) => switch (s) {
      ComplaintStatus.newComplaint => const Color(0xFFEEF0FF),
      ComplaintStatus.inProgress => const Color(0xFFFFF4E0),
      ComplaintStatus.awaitingStaff => const Color(0xFFFDEEEE),
      ComplaintStatus.resolved => const Color(0xFFE8F7EE),
      ComplaintStatus.reopened => const Color(0xFFF3E8FF),
    };

String fmtDateTime(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

String fmtBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: complaintStatusBg(status), borderRadius: BorderRadius.circular(999)),
      child: Text(
        complaintStatusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: complaintStatusColor(status)),
      ),
    );
  }
}

/// Complaints tab — staff view of their own complaints, mirroring the web
/// staff experience (submit, track status, read admin replies, reply back).
class ProtoComplaintsPage extends ConsumerWidget {
  const ProtoComplaintsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = [...ref.watch(protoStoreProvider).complaints]
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complaints', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.textPrimary)),
                      SizedBox(height: 3),
                      Text('Raise an issue privately — track replies and status here.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NewComplaintScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (complaints.isEmpty)
              _EmptyComplaints()
            else
              for (final c in complaints) ...[
                _ComplaintTile(complaint: c),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmptyComplaints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('No complaints yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('When you raise a complaint, its status and admin replies will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
        ],
      ),
    );
  }
}

class _ComplaintTile extends ConsumerWidget {
  const _ComplaintTile({required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        onTap: () {
          ref.read(protoStoreProvider.notifier).markComplaintRead(complaint.id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaintId: complaint.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(color: complaint.unreadByStaff ? const Color(0xFFCFC8F3) : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            complaint.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        if (complaint.unreadByStaff)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${complaint.reference} · ${fmtDateTime(complaint.lastMessageAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _StatusPill(status: complaint.status),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thread view — messages, attachments, status pill and a reply box.
class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _send() {
    final body = _reply.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    // Simulated send delay, mirroring the worklog save pattern.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(protoStoreProvider.notifier).replyToComplaint(widget.complaintId, body);
      _reply.clear();
      setState(() => _sending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final complaint = ref.watch(protoStoreProvider).complaints.where((c) => c.id == widget.complaintId).firstOrNull;
    if (complaint == null) {
      return Scaffold(appBar: AppBar(title: const Text('Complaint')), body: const Center(child: Text('Complaint not found.')));
    }
    final resolved = complaint.status == ComplaintStatus.resolved;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(complaint.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(complaint.reference, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Align(alignment: Alignment.centerLeft, child: _StatusPill(status: complaint.status)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                for (final m in complaint.messages) _MessageBubble(message: m),
                if (resolved)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF177A3D)),
                        SizedBox(width: 6),
                        Text('This complaint is resolved. Replies are closed.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF177A3D))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!resolved)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Write a reply…',
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: FilledButton(
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ComplaintMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.senderType == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(message.body, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
        ),
      );
    }
    final mine = message.senderType == 'staff';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.senderName}${message.senderRole != null ? ' · ${message.senderRole}' : ''}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: mine ? Colors.white.withValues(alpha: .75) : AppColors.textMuted),
            ),
            const SizedBox(height: 3),
            Text(
              message.body,
              style: TextStyle(fontSize: 14, height: 1.4, color: mine ? Colors.white : AppColors.textPrimary),
            ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final f in message.attachments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file_rounded, size: 14, color: mine ? Colors.white.withValues(alpha: .85) : AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${f.fileName} · ${fmtBytes(f.sizeBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mine ? Colors.white.withValues(alpha: .9) : AppColors.primary, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Text(
              fmtDateTime(message.createdAt),
              style: TextStyle(fontSize: 9, color: mine ? Colors.white.withValues(alpha: .6) : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// New complaint form — subject, description, attachments, evidence link.
class NewComplaintScreen extends ConsumerStatefulWidget {
  const NewComplaintScreen({super.key});

  @override
  ConsumerState<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _PickedFile {
  _PickedFile({required this.fileName, required this.sizeBytes, this.path});
  final String fileName;
  final int sizeBytes;
  final String? path;
}

class _NewComplaintScreenState extends ConsumerState<NewComplaintScreen> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  final List<_PickedFile> _files = [];
  bool _showLink = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions.toList(),
      );
      if (files.isEmpty || !mounted) return;
      setState(() {
        _error = null;
        for (final f in files) {
          final ext = f.extension ?? f.name.split('.').last.toLowerCase();
          final size = f.lengthSync() ?? 0;
          if (!_allowedExtensions.contains(ext)) {
            _error = '"${f.name}" has an unsupported file type.';
            continue;
          }
          if (size > _maxFileBytes) {
            _error = '"${f.name}" is larger than 10 MB.';
            continue;
          }
          if (_files.any((x) => x.fileName == f.name && x.sizeBytes == size)) continue;
          _files.add(_PickedFile(fileName: f.name, sizeBytes: size, path: f.path));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the file picker.');
    }
  }

  void _submit() {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    if (subject.length < 3) {
      setState(() => _error = 'Enter a subject.');
      return;
    }
    if (description.length < 10) {
      setState(() => _error = 'Describe the issue in more detail.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final files = [
        for (var i = 0; i < _files.length; i++)
          ComplaintFile(id: 'cf-new-$i', fileName: _files[i].fileName, sizeBytes: _files[i].sizeBytes, path: _files[i].path),
      ];
      ref.read(protoStoreProvider.notifier).addComplaint(
            subject: subject,
            description: description,
            files: files,
          );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted — the admin team will review it.'), behavior: SnackBarBehavior.floating),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log a complaint')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Raised privately for the admin team to review.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          _FieldLabel('Subject'),
          TextField(
            controller: _subject,
            maxLength: 140,
            decoration: const InputDecoration(hintText: 'Brief summary of the issue', counterText: ''),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Description'),
          TextField(
            controller: _description,
            minLines: 5,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: 'Describe what happened, when, and who was involved…'),
          ),
          const SizedBox(height: 20),
          _FieldLabel('Attachments (optional)'),
          // Two-button row matching the web evidence pattern.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file_rounded, size: 17),
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
          const Text('PDF, Office docs, CSV, TXT or images — up to 10 MB each.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _files.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Icon(_files[i].fileName.toLowerCase().endsWith('.png') || _files[i].fileName.toLowerCase().endsWith('.jpg') || _files[i].fileName.toLowerCase().endsWith('.jpeg') || _files[i].fileName.toLowerCase().endsWith('.webp') ? Icons.image_outlined : Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_files[i].fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text(fmtBytes(_files[i].sizeBytes), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _files.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ],
          if (_showLink) ...[
            const SizedBox(height: 14),
            _FieldLabel('Evidence link'),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://', prefixIcon: Icon(Icons.link_rounded, size: 18)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Text('Submit complaint'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}
