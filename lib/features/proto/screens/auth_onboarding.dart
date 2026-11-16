import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../mock_data.dart';
import '../proto_store.dart';

String fmtMin(int min) {
  final h = (min ~/ 60).toString().padLeft(2, '0');
  final m = (min % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String fmtDur(int min) {
  if (min < 60) return '${min}m';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Prototype welcome — simulated Google sign-in + discreet scenario picker.
class ProtoWelcomeScreen extends ConsumerWidget {
  const ProtoWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: const Color(0xFF27AE60), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.bolt, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('WorkTrack', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('Record work accurately. Stay aligned with your team.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666783))),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _pickScenario(context, ref),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF27AE60), minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(protoStoreProvider.notifier).signIn('new'),
                child: const Text('Prototype: skip sign-in (new employee)', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickScenario(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Prototype scenario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Demo only — pick the account type to preview.', style: TextStyle(fontSize: 12, color: Color(0xFF8B8B9A))),
              const SizedBox(height: 16),
              for (final (key, title, sub) in [
                ('new', 'New employee', 'Self-service registration'),
                ('invite', 'Invited employee', 'Pre-configured by admin'),
                ('returning', 'Existing employee', 'Bypasses onboarding'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(key == 'new' ? Icons.person_add : key == 'invite' ? Icons.mail_outline : Icons.person, color: const Color(0xFF27AE60)),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(protoStoreProvider.notifier).signIn(key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding — arrangement → client (client-site only) → profile.
class ProtoOnboardingScreen extends ConsumerStatefulWidget {
  const ProtoOnboardingScreen({super.key});
  @override
  ConsumerState<ProtoOnboardingScreen> createState() => _ProtoOnboardingScreenState();
}

class _ProtoOnboardingScreenState extends ConsumerState<ProtoOnboardingScreen> {
  int _step = 0;
  WorkArrangement? _arrangement;
  String? _clientId;
  final _name = TextEditingController(text: 'Demo Employee');
  final _title = TextEditingController();
  final _dept = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _title.dispose(); _dept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your account'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 4, borderRadius: BorderRadius.circular(4), color: const Color(0xFF27AE60)),
              const SizedBox(height: 24),
              Expanded(child: _buildStep()),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 13))),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF27AE60), minimumSize: const Size.fromHeight(50)),
                child: Text(_step == 2 ? 'Complete setup' : 'Continue'),
              ),
              if (_step > 0)
                TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Where do you work?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('This determines the tools and reports you will see.', style: TextStyle(color: Color(0xFF666783), fontSize: 13)),
        const SizedBox(height: 20),
        _OptionCard(icon: Icons.business, title: 'In-house', subtitle: 'Internal projects, tasks and subtasks.',
            selected: _arrangement == WorkArrangement.inHouse, onTap: () => setState(() => _arrangement = WorkArrangement.inHouse)),
        const SizedBox(height: 12),
        _OptionCard(icon: Icons.location_on_outlined, title: 'Client-site', subtitle: 'Report against a client\'s category catalogue.',
            selected: _arrangement == WorkArrangement.clientSite, onTap: () => setState(() => _arrangement = WorkArrangement.clientSite)),
      ]);
    }
    if (_step == 1 && _arrangement == WorkArrangement.clientSite) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Which client do you work for?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        for (final c in MockData.clients)
          _OptionCard(icon: Icons.apartment, title: c.name, subtitle: 'Client organisation',
              selected: _clientId == c.id, onTap: () => setState(() => _clientId = c.id)),
      ]);
    }
    // profile step (index 1 for in-house, 2 for client-site)
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Center(child: CircleAvatar(radius: 36, backgroundColor: const Color(0xFF27AE60).withValues(alpha: .12), child: const Icon(Icons.person, size: 36, color: Color(0xFF27AE60)))),
      const SizedBox(height: 16),
      _field('Full name', _name),
      _field('Job title', _title, hint: 'e.g. Support Engineer'),
      _field('Department', _dept, hint: 'e.g. Client Services'),
      const SizedBox(height: 8),
      Text('Employer: ${MockData.employer.name}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B8B9A))),
    ]);
  }

  Widget _field(String label, TextEditingController c, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white),
    ),
  );

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_arrangement == null) { setState(() => _error = 'Choose where you work.'); return; }
      setState(() => _step = _arrangement == WorkArrangement.clientSite ? 1 : 2);
    } else if (_step == 1 && _arrangement == WorkArrangement.clientSite) {
      if (_clientId == null) { setState(() => _error = 'Select a client organisation.'); return; }
      ref.read(protoStoreProvider.notifier)
        ..setArrangement(_arrangement!)
        ..setClient(_clientId!)
        ..completeOnboarding(name: _name.text, jobTitle: _title.text, department: _dept.text);
    } else {
      // in-house profile step OR fallthrough guard
      ref.read(protoStoreProvider.notifier)
        ..setArrangement(_arrangement ?? WorkArrangement.inHouse)
        ..completeOnboarding(name: _name.text, jobTitle: _title.text, department: _dept.text);
    }
    if (_step < 2) setState(() => _step++);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon; final String title; final String subtitle; final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF27AE60) : const Color(0xFFE8E6F2), width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? const Color(0xFF27AE60) : const Color(0xFF8B8B9A)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF666783))),
          ])),
          if (selected) const Icon(Icons.check_circle, color: Color(0xFF27AE60)),
        ]),
      ),
    );
  }
}
