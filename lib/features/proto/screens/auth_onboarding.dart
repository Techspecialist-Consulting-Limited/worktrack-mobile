import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../models.dart';
import '../mock_data.dart';
import '../proto_store.dart';

String fmtMin(int min) {
  final h = (min ~/ 60).toString().padLeft(2, '0');
  final m = (min % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

String fmtDur(int min) {
  if (min <= 0) return '0m';
  if (min < 60) return '${min}m';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Welcome / sign-in — simulated auth routes into onboarding.
class ProtoWelcomeScreen extends ConsumerStatefulWidget {
  const ProtoWelcomeScreen({super.key});
  @override
  ConsumerState<ProtoWelcomeScreen> createState() => _ProtoWelcomeScreenState();
}

class _ProtoWelcomeScreenState extends ConsumerState<ProtoWelcomeScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).signIn();
    if (mounted) setState(() => _busy = false);
  }

  /// Clears the stale cached session and forces a fresh Microsoft sign-in.
  Future<void> _reSignIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).reSignIn();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) setState(() => _busy = false);
  }

  Widget _stagger(int index, Widget child, {double dy = 18}) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(parent: _intro, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, (1 - anim.value) * dy), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authError = ref.watch(authControllerProvider.select((a) => a.errorMessage));
    final authBusy = ref.watch(authControllerProvider.select((a) => a.busy));
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.32,
            child: CustomPaint(painter: _WavePainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    children: [
                      _stagger(
                        0,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: .28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.bolt, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'WorkTrack',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        dy: -10,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),
                            _stagger(
                              1,
                              const Text(
                                'Track your work,\ndrive productivity',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.6,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _stagger(
                              2,
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: const Text(
                                  'Log your daily activities, manage tasks and stay aligned with your team.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, height: 1.55, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Flexible(
                              child: _stagger(
                                3,
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: c.maxWidth > 360 ? 340 : (c.maxWidth - 8).clamp(0.0, double.infinity),
                                    maxHeight: 220,
                                  ),
                                  child: Image.asset(
                                    'assets/images/worktrack_welcome_illustration.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                dy: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _stagger(
                        4,
                        SizedBox(
                          width: double.infinity,
                          child: _GoogleButton(busy: _busy || authBusy, onPressed: _signIn),
                        ),
                        dy: 14,
                      ),
                      const SizedBox(height: 18),
                      _stagger(
                        5,
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              authError ?? 'Access your WorkTrack workspace.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: authError != null ? AppColors.error : AppColors.textMuted,
                              ),
                            ),
                            // Re-authenticating cannot fix missing Entra config,
                            // so only offer the recovery action when configured.
                            if (authError != null && AppConfig.isConfigured) ...[
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: _busy || authBusy ? null : _reSignIn,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Clear session & sign in again'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ),
                            ],
                            if (AppConfig.isConfigured) ...[
                              TextButton.icon(
                                onPressed: _busy || authBusy ? null : _signOut,
                                icon: const Icon(Icons.logout, size: 16),
                                label: const Text('Sign out and clear saved account'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ),
                            ],
                          ],
                        ),
                        dy: 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MicrosoftG extends StatelessWidget {
  const _MicrosoftG({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MicrosoftGPainter());
}

class _MicrosoftGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 21;
    final w = 9.0;
    final h = 9.0;
    // Grid units (multiplied by s below): two 9×9 squares, 2-unit gap.
    final colors = [
      (const Offset(0, 1), const Color(0xFFF25022)), // top-left red
      (const Offset(11, 1), const Color(0xFF7FBA00)), // top-right green
      (const Offset(0, 12), const Color(0xFF00A4EF)), // bottom-left blue
      (const Offset(11, 12), const Color(0xFFFFB900)), // bottom-right yellow
    ];
    for (final (offset, color) in colors) {
      canvas.drawRect(
        Rect.fromLTWH(offset.dx * s, offset.dy * s, w * s, h * s),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MicrosoftG(size: 20),
                      SizedBox(width: 12),
                      Text('Sign in with Microsoft', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withValues(alpha: .06);
    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.15, size.width * 0.5, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.75, size.width, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Onboarding — arrangement → (client for client-site) → profile.
class ProtoOnboardingScreen extends ConsumerStatefulWidget {
  const ProtoOnboardingScreen({super.key});
  @override
  ConsumerState<ProtoOnboardingScreen> createState() => _ProtoOnboardingScreenState();
}

class _ProtoOnboardingScreenState extends ConsumerState<ProtoOnboardingScreen> {
  int _step = 0; // 0 arrangement, 1 client (client-site only), 2 profile
  WorkArrangement? _arrangement;
  String? _clientId;
  final _name = TextEditingController(text: 'Demo Employee');
  final _title = TextEditingController();
  final _dept = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _dept.dispose();
    super.dispose();
  }

  int get _totalSteps => _arrangement == WorkArrangement.clientSite ? 3 : 2;
  int get _displayStep {
    if (_step == 0) return 1;
    if (_step == 1 && _arrangement == WorkArrangement.clientSite) return 2;
    return _totalSteps;
  }

  bool get _isProfileStep => _step == 2 || (_step == 1 && _arrangement == WorkArrangement.inHouse);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Set up your account',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                      Text('Step $_displayStep of $_totalSteps', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: _displayStep / _totalSteps),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE8E6F2),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey('${_step}_${_arrangement?.name ?? 'none'}'),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: _buildStep(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isProfileStep ? 'Complete setup' : 'Continue'),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 4),
                    TextButton(onPressed: _back, child: const Text('Back')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where do you work?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Choose your work arrangement so we can set up the right tools and reporting for you.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          _OptionCard(
            icon: Icons.business_center_outlined,
            title: 'In-house',
            subtitle: 'Internal projects, tasks and subtasks.',
            selected: _arrangement == WorkArrangement.inHouse,
            onTap: () => setState(() { _arrangement = WorkArrangement.inHouse; _error = null; }),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.location_on_outlined,
            title: 'Client-site',
            subtitle: "Report against a client's category catalogue.",
            selected: _arrangement == WorkArrangement.clientSite,
            onTap: () => setState(() { _arrangement = WorkArrangement.clientSite; _error = null; }),
          ),
        ],
      );
    }
    if (_step == 1 && _arrangement == WorkArrangement.clientSite) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Which client do you work for?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Select the client organisation you are assigned to.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          for (int i = 0; i < MockData.clients.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.apartment_outlined,
              title: MockData.clients[i].name,
              subtitle: 'Client organisation',
              selected: _clientId == MockData.clients[i].id,
              onTap: () => setState(() { _clientId = MockData.clients[i].id; _error = null; }),
            ),
          ],
        ],
      );
    }

    // Profile
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add the details your team will see in WorkTrack.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.lavender,
                  child: Text(
                    _initials(_name.text),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Profile photo', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _field('Full name', _name, hint: 'Enter your full name', validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required.' : null),
          _field('Job title', _title, hint: 'e.g. Support Engineer'),
          _field('Department', _dept, hint: 'e.g. Client Services'),
          const SizedBox(height: 4),
          _EmployerCard(name: MockData.employer.name),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, String? Function(String?)? validator}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          validator: validator,
          onChanged: (_) { if (_step != 0) setState(() {}); },
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  void _back() {
    setState(() {
      _error = null;
      if (_step == 2 && _arrangement == WorkArrangement.inHouse) {
        _step = 0;
      } else if (_step > 0) {
        _step--;
      }
    });
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_arrangement == null) { setState(() => _error = 'Select where you work to continue.'); return; }
      setState(() => _step = _arrangement == WorkArrangement.clientSite ? 1 : 2);
      return;
    }
    if (_step == 1 && _arrangement == WorkArrangement.clientSite) {
      if (_clientId == null) { setState(() => _error = 'Select a client organisation to continue.'); return; }
      setState(() => _step = 2);
      return;
    }

    // Profile / complete
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) return;
    final store = ref.read(protoStoreProvider.notifier);
    store.setArrangement(_arrangement ?? WorkArrangement.inHouse);
    if (_arrangement == WorkArrangement.clientSite && _clientId != null) {
      store.setClient(_clientId!);
    }
    store.completeOnboarding(name: _name.text, jobTitle: _title.text, department: _dept.text);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.primary : AppColors.borderStrong;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.995,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.lavender : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: selected ? 1.6 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: .75) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    key: ValueKey(selected),
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployerCard extends StatelessWidget {
  const _EmployerCard({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.business_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employer organisation', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
