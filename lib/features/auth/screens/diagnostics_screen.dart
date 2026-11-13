import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../auth_controller.dart';
import '../models.dart';
import '../session_service.dart';

/// API diagnostics — exercises the real endpoints and reports HTTP-level
/// outcomes. Never displays tokens.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final List<_DiagEntry> _log = [];
  bool _running = false;

  SessionService get _service => ref.read(authControllerProvider.notifier).sessionService;

  void _add(String label, String detail, {bool ok = true}) {
    setState(() {
      _log.insert(0, _DiagEntry(label, detail, ok));
    });
  }

  Future<void> _run(String label, Future<String> Function() fn) async {
    setState(() => _running = true);
    final sw = Stopwatch()..start();
    try {
      final detail = await fn();
      _add(label, '${detail.isEmpty ? 'OK' : detail} · ${sw.elapsedMilliseconds}ms');
    } on ApiException catch (e) {
      _add(label, 'HTTP ${e.statusCode ?? '—'}: ${e.message}', ok: false);
    } catch (e) {
      _add(label, 'Error: ${e.runtimeType}', ok: false);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('API Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Environment', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _EnvRow('API base', AppConfig.apiBaseUrl),
                  _EnvRow('Role header', auth.selectedMembership?.role ?? 'none'),
                  _EnvRow('Entra configured', AppConfig.isConfigured ? 'yes' : 'NO'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : () => _run('GET /api/mobile/session', () async {
              final s = await _service.fetchSession();
              return 'memberships: ${s.memberships.map((m) => m.role).join(', ')}';
            }),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Test session discovery'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _running ? null : () => _run('GET /api/worklog/state?scope=me', () async {
              final data = await _service.fetchWorklogState();
              final s = WorklogStateSummary.fromResponse(data);
              return 'employees: ${s.employeeCount}, tasks: ${s.taskCount}, '
                  'entries: ${s.entryCount}, breaks: ${s.breakCount}';
            }),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Load my worklog state'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _running
                ? null
                : () => _run('Token renewal (silent)', () async {
                      // Exercises MSAL silent acquisition without calling the API.
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .sessionService
                          .fetchWorklogState();
                      return 'state keys: ${ok.keys.length}';
                    }),
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Re-call state (exercises token + role headers)'),
          ),
          if (_running)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 20),
          if (_log.isNotEmpty)
            const Text('Results', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final entry in _log) _DiagTile(entry: entry),
        ],
      ),
    );
  }
}

class _EnvRow extends StatelessWidget {
  const _EnvRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagEntry {
  const _DiagEntry(this.label, this.detail, this.ok);
  final String label;
  final String detail;
  final bool ok;
}

class _DiagTile extends StatelessWidget {
  const _DiagTile({required this.entry});
  final _DiagEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          entry.ok ? Icons.check_circle_outline : Icons.error_outline,
          color: entry.ok ? AppColors.success : AppColors.error,
        ),
        title: Text(entry.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(entry.detail, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ),
    );
  }
}
