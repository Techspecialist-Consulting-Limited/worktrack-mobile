import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_controller.dart';
import '../models.dart';
import '../session_service.dart';

/// Authenticated home: identity summary + connection status + diagnostics.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  WorklogStateSummary? _summary;
  String? _orgLine;
  bool _loadingProfile = true;
  String? _profileError;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final data = await ref.read(authControllerProvider.notifier).sessionService.fetchWorklogState();
      final summary = WorklogStateSummary.fromResponse(data);
      String? org;
      final db = data['db'] as Map<String, dynamic>?;
      final employees = db?['employees'] as List? ?? const [];
      if (employees.isNotEmpty && employees.first is Map) {
        final emp = employees.first as Map;
        org = (emp['employerOrganisationName'] ?? emp['clientOrganisationName']) as String?;
      }
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _orgLine = org;
        _lastSync = DateTime.now();
        _loadingProfile = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = e.message;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileError = 'Could not load your profile.';
        _loadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final membership = auth.selectedMembership;
    final session = auth.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkTrack'),
        actions: [
          IconButton(
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => context.push('/diagnostics'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'switch') {
                ref.read(authControllerProvider.notifier).switchRole();
              } else if (v == 'signout') {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'switch', child: Text('Switch role')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            _initials(membership?.employeeName ?? session?.name),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                membership?.employeeName ?? session?.name ?? 'Team member',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                session?.email ?? '',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _InfoRow(label: 'Role', value: membership?.roleLabel ?? '—'),
                    _InfoRow(label: 'Organisation', value: _orgLine ?? (_loadingProfile ? 'Loading…' : '—')),
                    _InfoRow(
                      label: 'Permissions',
                      value: membership?.isConfigAdmin == true ? 'Config admin' : 'Standard',
                    ),
                    _InfoRow(
                      label: 'Connection',
                      value: _profileError == null ? 'Connected' : 'Degraded',
                      valueColor: _profileError == null ? AppColors.success : AppColors.warning,
                    ),
                    if (_lastSync != null)
                      _InfoRow(
                        label: 'Last sync',
                        value: _formatTime(_lastSync!),
                      ),
                  ],
                ),
              ),
            ),
            if (_loadingProfile)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_profileError != null)
              Card(
                color: const Color(0xFFFFFBEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _profileError!,
                          style: const TextStyle(fontSize: 13, color: AppColors.warning),
                        ),
                      ),
                      TextButton(onPressed: _loadProfile, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_summary != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s workspace',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat(label: 'Tasks', value: '${_summary!.taskCount}'),
                          _Stat(label: 'Entries', value: '${_summary!.entryCount}'),
                          _Stat(label: 'Breaks', value: '${_summary!.breakCount}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
