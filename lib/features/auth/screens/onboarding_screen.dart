import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_controller.dart';
import '../session_service.dart' show ApiException;

/// Self-service staff onboarding for identities with no WorkTrack
/// membership yet (accessState 'none'). Submits to
/// POST /api/mobile/onboarding — the same rules as the web flow.
class LiveOnboardingScreen extends ConsumerStatefulWidget {
  const LiveOnboardingScreen({super.key});

  @override
  ConsumerState<LiveOnboardingScreen> createState() => _LiveOnboardingScreenState();
}

class _LiveOnboardingScreenState extends ConsumerState<LiveOnboardingScreen> {
  String? _arrangement; // 'in_house' | 'client_site'
  String? _clientOrgId;
  List<Map<String, dynamic>> _clientOrgs = const [];
  bool _loadingOrgs = false;
  final _title = TextEditingController();
  final _dept = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClientOrgs();
  }

  Future<void> _loadClientOrgs() async {
    setState(() => _loadingOrgs = true);
    try {
      final orgs = await ref.read(authControllerProvider.notifier).sessionService.fetchClientOrganisations();
      if (mounted) setState(() => _clientOrgs = orgs);
    } catch (_) {/* picker stays empty; in-house still works */}
    if (mounted) setState(() => _loadingOrgs = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _dept.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_arrangement == null) {
      setState(() => _error = 'Choose your work arrangement.');
      return;
    }
    if (_arrangement == 'client_site' && _clientOrgId == null) {
      setState(() => _error = 'Select the client you work for.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sessionService.completeOnboarding(
            workArrangement: _arrangement!,
            clientOrganisationId: _arrangement == 'client_site' ? _clientOrgId : null,
            jobTitle: _title.text.trim().isEmpty ? null : _title.text.trim(),
            department: _dept.text.trim().isEmpty ? null : _dept.text.trim(),
          );
      // Membership now exists — re-resolve session → role selection/ready.
      await ref.read(authControllerProvider.notifier).refreshSession();
    } on ApiException catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Registration failed. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            auth.session?.name ?? auth.session?.email ?? 'Welcome',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete your staff profile to start logging work.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          const _Label('Where do you work?'),
          _Option(
            icon: Icons.business_center_outlined,
            title: 'In-house',
            subtitle: 'Internal projects, tasks and subtasks.',
            selected: _arrangement == 'in_house',
            onTap: () => setState(() { _arrangement = 'in_house'; _error = null; }),
          ),
          const SizedBox(height: 10),
          _Option(
            icon: Icons.location_on_outlined,
            title: 'Client-site',
            subtitle: "Report against a client's category catalogue.",
            selected: _arrangement == 'client_site',
            onTap: () => setState(() { _arrangement = 'client_site'; _error = null; }),
          ),
          if (_arrangement == 'client_site') ...[
            const SizedBox(height: 16),
            const _Label('Which client do you work for?'),
            if (_loadingOrgs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_clientOrgs.isEmpty)
              const Text(
                'No client organisations are available yet — ask your administrator to set one up, or choose In-house.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              )
            else
              for (final o in _clientOrgs) ...[
                _Option(
                  icon: Icons.apartment_outlined,
                  title: o['name'] as String? ?? '',
                  subtitle: 'Client organisation',
                  selected: _clientOrgId == o['id'],
                  onTap: () => setState(() { _clientOrgId = o['id'] as String?; _error = null; }),
                ),
                const SizedBox(height: 10),
              ],
          ],
          const SizedBox(height: 20),
          const _Label('Job title (optional)'),
          _Field(controller: _title, hint: 'e.g. Support Engineer'),
          const SizedBox(height: 14),
          const _Label('Department (optional)'),
          _Field(controller: _dept, hint: 'e.g. Client Services'),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Complete setup'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.lavender : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(hintText: hint, isDense: true),
    );
  }
}
