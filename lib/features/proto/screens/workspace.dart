import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../models.dart';
import '../mock_data.dart';
import '../proto_store.dart';
import '../widgets/proto_fields.dart';
import 'auth_onboarding.dart' show fmtDur;
import 'complaints.dart' show ProtoComplaintsPage, fmtBytes;
import 'log_work.dart';

/// Bottom-nav shell: Home / My Work / Tasks / Complaints / Profile.
class ProtoShell extends ConsumerStatefulWidget {
  const ProtoShell({super.key});
  @override
  ConsumerState<ProtoShell> createState() => _ProtoShellState();
}

class _ProtoShellState extends ConsumerState<ProtoShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    ref.listen(protoStoreProvider.select((s) => s.liveError), (prev, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next), behavior: SnackBarBehavior.floating));
        ref.read(protoStoreProvider.notifier).clearLiveError();
      }
    });
    final unread = ref.watch(protoStoreProvider.select((s) => s.unreadComplaintCount));
    final pages = [
      ProtoHomePage(
        onProfileTap: () => setState(() => _tab = 4),
        onViewAll: () => setState(() => _tab = 1),
        onComplaintsTap: () => setState(() => _tab = 3),
      ),
      const ProtoMyWorkPage(),
      const ProtoTasksPage(),
      const ProtoComplaintsPage(),
      const ProtoProfilePage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.work_history_outlined), selectedIcon: Icon(Icons.work_history_rounded), label: 'My Work'),
            const NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist_rounded), label: 'Tasks'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                backgroundColor: AppColors.error,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                backgroundColor: AppColors.error,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Complaints',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String formatLongDate(DateTime d) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  return parts.map((p) => p[0].toUpperCase()).take(2).join();
}

class DaySummary {
  const DaySummary({required this.productiveMin, required this.overtimeMin, required this.breakMin});
  final int productiveMin;
  final int overtimeMin;
  final int breakMin;

  static DaySummary compute(List<WorkEntry> entries) {
    var productive = 0, overtime = 0, brk = 0;
    for (final e in entries) {
      if (e.kind == EntryKind.breakEntry) {
        brk += e.durationMin;
        continue;
      }
      productive += e.durationMin;
      if (e.isOvertime) overtime += e.durationMin;
    }
    return DaySummary(productiveMin: productive, overtimeMin: overtime, breakMin: brk);
  }
}

class ProtoHomePage extends ConsumerWidget {
  const ProtoHomePage({super.key, this.onProfileTap, this.onViewAll, this.onComplaintsTap});
  final VoidCallback? onProfileTap;
  final VoidCallback? onViewAll;
  final VoidCallback? onComplaintsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = [
      for (final en in s.entries)
        if (en.day.year == today.year && en.day.month == today.month && en.day.day == today.day) en,
    ];
    final sum = DaySummary.compute(entries);
    final firstName = e.name.trim().isEmpty ? 'there' : e.name.trim().split(RegExp(r'\s+')).first;
    final workEntries = entries.where((x) => x.kind == EntryKind.work).toList()..sort((a, b) => b.startMin.compareTo(a.startMin));
    final preview = workEntries.take(3).toList();
    final greeting = '${greetingFor(now)}, $firstName';
    final dateLabel = formatLongDate(now);

    final workplace = e.workArrangement == WorkArrangement.clientSite
        ? _orgName(s, e.clientOrgId ?? e.employerOrgId)
        : 'In-house';

    Widget appear(int index, Widget child) {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduce) return child;
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + (index * 45).clamp(0, 220)),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: child),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            appear(
              0,
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .22), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('WorkTrack', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary)),
                  ),
                  _NotificationBell(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.lavender,
                        child: Text(initialsOf(e.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            appear(
              1,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(greeting, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary, height: 1.15)),
                              const SizedBox(height: 2),
                              Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        _InfoPill(icon: e.workArrangement == WorkArrangement.clientSite ? Icons.location_on_outlined : Icons.business_center_outlined, label: workplace),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            appear(2, _ProgressCard(summary: sum)),
            if (s.activeBreak != null) ...[
              const SizedBox(height: 10),
              appear(3, _ActiveBreakCard(startedAt: s.activeBreak!.startedAt)),
            ],
            const SizedBox(height: 10),
            appear(
              4,
              Row(
                children: [
                  _MiniStat(label: 'Productive', value: fmtDur(sum.productiveMin), color: AppColors.primary),
                  const SizedBox(width: 8),
                  _MiniStat(label: 'Overtime', value: fmtDur(sum.overtimeMin), color: const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _MiniStat(label: 'Breaks', value: fmtDur(sum.breakMin), color: const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            appear(
              5,
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _BreathingActionButton(
                      onPressed: s.activeBreak != null
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProtoLogWorkScreen())),
                      icon: Icons.add_rounded,
                      label: s.activeBreak != null ? 'On break' : 'Log work',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _toggleBreak(context, ref),
                      icon: Icon(s.activeBreak != null ? Icons.stop_rounded : Icons.coffee_rounded, size: 18),
                      label: Text(s.activeBreak != null ? 'End break' : 'Start break'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: s.activeBreak != null ? const Color(0xFFB45309) : Colors.white,
                        foregroundColor: s.activeBreak != null ? Colors.white : AppColors.textPrimary,
                        side: s.activeBreak != null ? BorderSide.none : const BorderSide(color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (s.unreadComplaintCount > 0) ...[
              const SizedBox(height: 10),
              appear(
                6,
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onComplaintsTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCFC8F3))),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: const Color(0xFFFDEEEE), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: AppColors.error),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${s.unreadComplaintCount} unread complaint update${s.unreadComplaintCount == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            appear(
              5,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Latest activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2)),
                        SizedBox(height: 2),
                        Text("Today's work entries", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (workEntries.isNotEmpty)
                    TextButton(
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                      child: const Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (preview.isEmpty)
              appear(
                6,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text('No work logged yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Record your first activity for today to see it here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                appear(6 + i, _ActivityCard(entry: preview[i], tasks: s.tasks, state: s)),
              ],
          ],
        ),
      ),
    );
  }
}

/// Purple daily-progress card — productive time vs the 8h target.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    const target = 8 * 60;
    final progress = (summary.productiveMin / target).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final remaining = (target - summary.productiveMin).clamp(0, target);
    final status = summary.productiveMin >= target
        ? 'Daily target reached'
        : summary.productiveMin == 0
            ? 'Start logging your day'
            : '${fmtDur(remaining)} left of 8h';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFF), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .24), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's progress", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .86))),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtDur(summary.productiveMin), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white, height: 1)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('productive', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: .18),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$pct% · $status', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .14),
              border: Border.all(color: Colors.white.withValues(alpha: .2)),
            ),
            child: Center(
              child: Text('$pct%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _BreathingActionButton extends StatefulWidget {
  const _BreathingActionButton({required this.onPressed, required this.icon, required this.label});
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  State<_BreathingActionButton> createState() => _BreathingActionButtonState();
}

class _BreathingActionButtonState extends State<_BreathingActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final button = FilledButton.icon(
      onPressed: widget.onPressed,
      icon: Icon(widget.icon, size: 20),
      label: Text(widget.label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    );
    if (reduce) return button;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1 + (t * 0.02);
        final glow = 0.12 + (t * 0.10);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: glow), blurRadius: 14 + (t * 8), spreadRadius: 0.5)],
            ),
            child: child,
          ),
        );
      },
      child: button,
    );
  }
}

void _toggleBreak(BuildContext context, WidgetRef ref) {
  final store = ref.read(protoStoreProvider.notifier);
  if (store.isOnBreak) {
    final minutes = store.endBreak();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Break ended${minutes != null ? ' · ${fmtDur(minutes)} recorded' : ''}'), behavior: SnackBarBehavior.floating),
    );
  } else {
    store.startBreak();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Break started — remember to end it when you\'re back.'), behavior: SnackBarBehavior.floating),
    );
  }
}

/// Live break countdown — amber card, ticks every second, shows overrun past
/// the 60-minute allowance. Elapsed is computed from the persisted start.
class _ActiveBreakCard extends ConsumerStatefulWidget {
  const _ActiveBreakCard({required this.startedAt});
  final DateTime startedAt;

  @override
  ConsumerState<_ActiveBreakCard> createState() => _ActiveBreakCardState();
}

class _ActiveBreakCardState extends ConsumerState<_ActiveBreakCard> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _clock(Duration d) {
    final total = d.inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = h > 0 ? '$h:${m.toString().padLeft(2, '0')}' : m.toString().padLeft(2, '0');
    return '$mm:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final allowance = const Duration(minutes: ProtoStore.breakAllowanceMin);
    final over = elapsed > allowance;
    final label = over ? '${_clock(elapsed - allowance)} over' : '${_clock(allowance - elapsed)} remaining';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D9A4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFFDEBD3), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.coffee_rounded, size: 19, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(over ? 'Break time exceeded' : 'On break', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8A5A00))),
                const SizedBox(height: 1),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _toggleBreak(context, ref),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8A5A00), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            child: const Text('End break'),
          ),
        ],
      ),
    );
  }
}

/// Notification bell with unread indicator — opens a mock notifications sheet.
class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SafeArea(
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded, size: 34, color: AppColors.textMuted),
                SizedBox(height: 10),
                Text('No new notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text('You\'re all caught up.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
      icon: Badge(
        isLabelVisible: true,
        smallSize: 8,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.notifications_none_rounded, size: 22),
      ),
      color: AppColors.textPrimary,
      tooltip: 'Notifications',
      style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, height: 1.1)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entry, required this.tasks, required this.state});
  final WorkEntry entry;
  final List<Task> tasks;
  final ProtoState state;

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(entry, state);
    final subtitle = _subtitleFor(entry);
    final status = _statusFor(entry);
    final accent = entry.clientCategoryId != null ? const Color(0xFF0EA5E9) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withValues(alpha: .18), accent.withValues(alpha: .08)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.clientCategoryId != null ? Icons.apartment_rounded : Icons.assignment_rounded, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                      child: Text('${fmtTime12(entry.startMin)} – ${fmtTime12(entry.endMin)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ),
                    const Spacer(),
                    Text(fmtDur(entry.durationMin), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (status != null || entry.isOvertime) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (entry.isOvertime) const _Tag(label: 'Overtime', color: Color(0xFFF59E0B)),
                      if (status != null) _Tag(label: status, color: _statusColor(status)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(WorkEntry en, ProtoState s) {
    if (en.taskId != null) {
      final task = tasks.where((t) => t.id == en.taskId).cast<Task?>().firstWhere((t) => t != null, orElse: () => null);
      final project = task != null ? _projectName(s, task.projectId) : _projectName(s, '');
      final taskTitle = task?.title ?? _taskTitle(s, en.taskId!);
      return '$project · $taskTitle';
    }
    return '${_categoryName(s, en.clientCategoryId ?? '')} · ${_subcategoryName(s, en.clientSubcategoryId ?? '')}';
  }

  String _subtitleFor(WorkEntry en) => en.description.trim();

  Color _statusColor(String status) => switch (status) {
        'Done' => const Color(0xFF16A34A),
        'Ongoing' => AppColors.primary,
        'Blocked' => const Color(0xFFDC2626),
        _ => AppColors.textMuted,
      };

  String? _statusFor(WorkEntry en) {
    if (en.taskId == null) return null;
    final task = tasks.where((t) => t.id == en.taskId).cast<Task?>().firstWhere((t) => t != null, orElse: () => null);
    if (task == null) return null;
    switch (task.status) {
      case TaskStatus.ongoing:
        return 'Ongoing';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.blocked:
        return 'Blocked';
      case TaskStatus.dropped:
        return 'Dropped';
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

enum _DateFilter { today, yesterday, thisWeek, custom }

enum _EntryFilter { all, work, breaks, overtime }

/// My Work — recorded entries grouped by date with range + type filters.
class ProtoMyWorkPage extends ConsumerStatefulWidget {
  const ProtoMyWorkPage({super.key});

  @override
  ConsumerState<ProtoMyWorkPage> createState() => _ProtoMyWorkPageState();
}

class _ProtoMyWorkPageState extends ConsumerState<ProtoMyWorkPage> {
  _DateFilter _dateFilter = _DateFilter.thisWeek;
  _EntryFilter _entryFilter = _EntryFilter.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _today => _day(DateTime.now());

  bool _inRange(DateTime d) {
    final day = _day(d);
    switch (_dateFilter) {
      case _DateFilter.today:
        return _sameDay(day, _today);
      case _DateFilter.yesterday:
        return _sameDay(day, _today.subtract(const Duration(days: 1)));
      case _DateFilter.thisWeek:
        final weekStart = _today.subtract(Duration(days: _today.weekday - 1));
        return !day.isBefore(weekStart) && !day.isAfter(_today);
      case _DateFilter.custom:
        final start = _customStart == null ? null : _day(_customStart!);
        final end = _customEnd == null ? null : _day(_customEnd!);
        if (start == null || end == null) return false;
        final lo = start.isBefore(end) ? start : end;
        final hi = start.isBefore(end) ? end : start;
        return !day.isBefore(lo) && !day.isAfter(hi);
    }
  }

  bool _typeMatch(WorkEntry e) {
    switch (_entryFilter) {
      case _EntryFilter.all:
        return true;
      case _EntryFilter.work:
        return e.kind == EntryKind.work && !e.isOvertime;
      case _EntryFilter.breaks:
        return e.kind == EntryKind.breakEntry;
      case _EntryFilter.overtime:
        return e.kind == EntryKind.work && e.isOvertime;
    }
  }

  List<WorkEntry> _filtered(List<WorkEntry> all) {
    final list = [for (final e in all) if (_inRange(e.day) && _typeMatch(e)) e]
      ..sort((a, b) {
        final dc = b.day.compareTo(a.day);
        if (dc != 0) return dc;
        return b.startMin.compareTo(a.startMin);
      });
    return list;
  }

  Map<DateTime, List<WorkEntry>> _groupByDay(List<WorkEntry> entries) {
    final map = <DateTime, List<WorkEntry>>{};
    for (final e in entries) {
      final key = _day(e.day);
      (map[key] ??= []).add(e);
    }
    return map;
  }

  String _dayLabel(DateTime day) {
    final d = _day(day);
    if (_sameDay(d, _today)) return 'Today · ${formatLongDate(d)}';
    if (_sameDay(d, _today.subtract(const Duration(days: 1)))) return 'Yesterday · ${formatLongDate(d)}';
    return formatLongDate(d);
  }

  String get _rangeLabel {
    switch (_dateFilter) {
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.yesterday:
        return 'Yesterday';
      case _DateFilter.thisWeek:
        return 'This week';
      case _DateFilter.custom:
        if (_customStart != null && _customEnd != null) {
          final a = _day(_customStart!);
          final b = _day(_customEnd!);
          final lo = a.isBefore(b) ? a : b;
          final hi = a.isBefore(b) ? b : a;
          String short(DateTime x) => '${x.day}/${x.month}';
          return '${short(lo)} – ${short(hi)}';
        }
        return 'Custom range';
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    DateTime? start = _customStart ?? now.subtract(const Duration(days: 6));
    DateTime? end = _customEnd ?? now;
    start = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Range start',
    );
    if (start == null || !mounted) return;
    end = await showDatePicker(
      context: context,
      initialDate: end.isBefore(start) ? start : end,
      firstDate: start,
      lastDate: now,
      helpText: 'Range end',
    );
    if (end == null || !mounted) return;
    setState(() {
      _customStart = start;
      _customEnd = end;
      _dateFilter = _DateFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(protoStoreProvider);
    final filtered = _filtered(s.entries);
    final groups = _groupByDay(filtered);
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final rangeSum = DaySummary.compute(filtered);
    final workCount = filtered.where((e) => e.kind == EntryKind.work).length;

    Widget chip(bool selected, String label, VoidCallback onTap) {
      return Material(
        color: selected ? AppColors.lavender : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary)),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Work', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.textPrimary)),
                      SizedBox(height: 3),
                      Text('Review and manage your work activities.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _dateFilter = _DateFilter.thisWeek;
                    _entryFilter = _EntryFilter.all;
                    _customStart = null;
                    _customEnd = null;
                  }),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  color: AppColors.textPrimary,
                  tooltip: 'Reset filters',
                  style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Summary for the selected range
            _RangeSummaryCard(summary: rangeSum, entries: workCount, rangeLabel: _rangeLabel),
            const SizedBox(height: 16),
            // Date filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(_dateFilter == _DateFilter.today, 'Today', () => setState(() => _dateFilter = _DateFilter.today)),
                  const SizedBox(width: 8),
                  chip(_dateFilter == _DateFilter.yesterday, 'Yesterday', () => setState(() => _dateFilter = _DateFilter.yesterday)),
                  const SizedBox(width: 8),
                  chip(_dateFilter == _DateFilter.thisWeek, 'This week', () => setState(() => _dateFilter = _DateFilter.thisWeek)),
                  const SizedBox(width: 8),
                  chip(_dateFilter == _DateFilter.custom, _rangeLabel, _pickCustomRange),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Entry-type filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(_entryFilter == _EntryFilter.all, 'All entries', () => setState(() => _entryFilter = _EntryFilter.all)),
                  const SizedBox(width: 8),
                  chip(_entryFilter == _EntryFilter.work, 'Work', () => setState(() => _entryFilter = _EntryFilter.work)),
                  const SizedBox(width: 8),
                  chip(_entryFilter == _EntryFilter.breaks, 'Breaks', () => setState(() => _entryFilter = _EntryFilter.breaks)),
                  const SizedBox(width: 8),
                  chip(_entryFilter == _EntryFilter.overtime, 'Overtime', () => setState(() => _entryFilter = _EntryFilter.overtime)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    const Icon(Icons.work_history_outlined, color: AppColors.textMuted, size: 30),
                    const SizedBox(height: 8),
                    Text(_entryFilter == _EntryFilter.all && _dateFilter != _DateFilter.custom ? 'No work entries for this period.' : 'No entries match the selected filters.',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Try a different date range or entry type.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _dateFilter = _DateFilter.today;
                        _entryFilter = _EntryFilter.all;
                      }),
                      icon: const Icon(Icons.today_rounded, size: 16),
                      label: const Text('Back to today'),
                    ),
                  ],
                ),
              )
            else
              for (final day in days) ...[
                _DayHeader(label: _dayLabel(day), summary: DaySummary.compute(groups[day]!)),
                const SizedBox(height: 8),
                for (final entry in groups[day]!) ...[
                  _EntryTile(
                    entry: entry,
                    tasks: s.tasks,
                    state: s,
                    onTap: () => _showEntryDetails(context, ref, entry),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    );
  }
}

/// Compact summary card for the selected range — 4 derived metrics.
class _RangeSummaryCard extends StatelessWidget {
  const _RangeSummaryCard({required this.summary, required this.entries, required this.rangeLabel});
  final DaySummary summary;
  final int entries;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, height: 1.1)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Summary · $rangeLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              stat(fmtDur(summary.productiveMin), 'Productive', AppColors.primary),
              const SizedBox(width: 8),
              stat(fmtDur(summary.overtimeMin), 'Overtime', const Color(0xFFD97706)),
              const SizedBox(width: 8),
              stat(fmtDur(summary.breakMin), 'Breaks', const Color(0xFF059669)),
              const SizedBox(width: 8),
              stat('$entries', 'Entries', AppColors.textPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.summary});
  final String label;
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(999)),
            child: Text('${fmtDur(summary.productiveMin)} productive', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.tasks, required this.state, required this.onTap});
  final WorkEntry entry;
  final List<Task> tasks;
  final ProtoState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBreak = entry.kind == EntryKind.breakEntry;
    final title = isBreak ? 'Break' : _entryTitle(entry, tasks, state);
    final subtitle = isBreak ? _locationLabel(entry.location) : (entry.description.trim().isEmpty ? _locationLabel(entry.location) : '${entry.description.trim()} · ${_locationLabel(entry.location)}');
    final accent = isBreak ? const Color(0xFFF59E0B) : (entry.clientCategoryId != null ? const Color(0xFF0EA5E9) : AppColors.primary);
    final icon = isBreak ? Icons.coffee_rounded : (entry.clientCategoryId != null ? Icons.apartment_rounded : Icons.assignment_rounded);
    final status = isBreak ? null : _taskStatusFor(entry, tasks);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${fmtTime12(entry.startMin)} – ${fmtTime12(entry.endMin)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(fmtDur(entry.durationMin), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
                    if (!isBreak && (entry.isOvertime || status != null || entry.attachments.isNotEmpty || entry.evidenceLink != null)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (entry.isOvertime) const _Tag(label: 'Overtime', color: Color(0xFFF59E0B)),
                          if (status != null) _Tag(label: status.$1, color: status.$2),
                          if (entry.attachments.isNotEmpty)
                            _Tag(label: '${entry.attachments.length} attachment${entry.attachments.length == 1 ? '' : 's'}', color: const Color(0xFF0EA5E9)),
                          if (entry.evidenceLink != null) const _Tag(label: 'Link', color: AppColors.textSecondary),
                        ],
                      ),
                    ],
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

/// Task status for an entry's underlying task, if any — (label, colour).
(String, Color)? _taskStatusFor(WorkEntry en, List<Task> tasks) {
  if (en.taskId == null) return null;
  final task = tasks.where((t) => t.id == en.taskId).cast<Task?>().firstWhere((t) => t != null, orElse: () => null);
  if (task == null) return null;
  return switch (task.status) {
    TaskStatus.done => ('Done', const Color(0xFF16A34A)),
    TaskStatus.ongoing => ('Ongoing', AppColors.primary),
    TaskStatus.blocked => ('Blocked', const Color(0xFFDC2626)),
    TaskStatus.dropped => ('Dropped', AppColors.textMuted),
  };
}

String _entryTitle(WorkEntry en, List<Task> tasks, ProtoState s) {
  if (en.taskId != null) {
    final task = tasks.where((t) => t.id == en.taskId).cast<Task?>().firstWhere((t) => t != null, orElse: () => null);
    final project = task != null ? _projectName(s, task.projectId) : '';
    final taskTitle = task?.title ?? _taskTitle(s, en.taskId!);
    final parts = [project, taskTitle];
    if (en.subtaskId != null) {
      final sub = task?.subtasks.where((x) => x.id == en.subtaskId).firstOrNull;
      parts.add(sub?.title ?? en.subtaskId!);
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }
  return '${_categoryName(s, en.clientCategoryId ?? '')} · ${_subcategoryName(s, en.clientSubcategoryId ?? '')}';
}

/* Live-aware lookups — hydrated state first, mock fixtures as fallback. */
String _projectName(ProtoState s, String id) {
  for (final p in s.projects) {
    if (p.id == id) return p.name;
  }
  return MockData.projectName(id);
}

String _taskTitle(ProtoState s, String id) {
  for (final t in s.tasks) {
    if (t.id == id) return t.title;
  }
  return MockData.taskTitle(id);
}

String _categoryName(ProtoState s, String id) {
  for (final c in s.clientCategories) {
    if (c.id == id) return c.name;
  }
  return MockData.categoryName(id);
}

String _subcategoryName(ProtoState s, String id) {
  for (final x in s.clientSubcategories) {
    if (x.id == id) return x.name;
  }
  return MockData.subcategoryName(id);
}

String _orgName(ProtoState s, String id) => s.orgNames[id] ?? MockData.orgName(id);

String _locationLabel(WorkLocation loc) => switch (loc) {
      WorkLocation.office => 'Office',
      WorkLocation.home => 'Home',
      WorkLocation.clientSite => 'Client site',
    };

Future<void> _showEntryDetails(BuildContext context, WidgetRef ref, WorkEntry entry) async {
  final s = ref.read(protoStoreProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(entry.kind == EntryKind.breakEntry ? 'Break details' : 'Work entry details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 6),
              _DetailRow(label: 'Date', value: formatLongDate(entry.day)),
              _DetailRow(label: 'Time', value: '${fmtTime12(entry.startMin)} – ${fmtTime12(entry.endMin)}'),
              _DetailRow(label: 'Duration', value: fmtDur(entry.durationMin)),
              _DetailRow(label: 'Type', value: entry.kind == EntryKind.breakEntry ? 'Break' : (entry.isOvertime ? 'Work (Overtime)' : 'Work')),
              if (entry.kind == EntryKind.work) ...[
                _DetailRow(label: 'Activity', value: _entryTitle(entry, s.tasks, s)),
                if (entry.description.trim().isNotEmpty) _DetailRow(label: 'Description', value: entry.description.trim()),
              ],
              _DetailRow(label: 'Location', value: _locationLabel(entry.location)),
              if (entry.kind == EntryKind.work && entry.attachments.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Attachments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                for (final a in entry.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(a.isImage ? Icons.image_outlined : Icons.description_outlined, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${a.fileName} · ${fmtBytes(a.sizeBytes)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
              ],
              if (entry.kind == EntryKind.work && entry.evidenceLink != null && entry.evidenceLink!.isNotEmpty)
                _DetailRow(label: 'Evidence link', value: entry.evidenceLink!),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (entry.kind == EntryKind.work)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProtoLogWorkScreen(editing: entry)));
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                  if (entry.kind == EntryKind.work) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await _confirmDeleteEntry(context, entry);
                        if (ok == true) {
                          ref.read(protoStoreProvider.notifier).deleteEntry(entry.id);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry deleted'), behavior: SnackBarBehavior.floating));
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFEECEC), foregroundColor: AppColors.error, elevation: 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.35)),
        ],
      ),
    );
  }
}

/// Custom in-app delete confirmation — warning icon, consequences, destructive action.
Future<bool?> _confirmDeleteEntry(BuildContext context, WorkEntry entry) {
  var busy = false;
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 26),
              ),
              const SizedBox(height: 14),
              const Text('Delete work entry?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'This removes the ${fmtTime12(entry.startMin)} – ${fmtTime12(entry.endMin)} record from your work history. This cannot be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              setD(() => busy = true);
                              Navigator.of(ctx).pop(true);
                            },
                      icon: busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.delete_outline_rounded, size: 17),
                      label: Text(busy ? 'Deleting…' : 'Delete entry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Tasks — in-house hierarchy with status + progress notes, or client-site
/// category overview. Mirrors the web "Update Progress" workflow.
class ProtoTasksPage extends ConsumerWidget {
  const ProtoTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    final isClient = e.workArrangement == WorkArrangement.clientSite;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isClient ? 'Work categories' : 'My tasks', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(isClient ? 'The categories you can log time against.' : 'Track status and log progress on your assigned tasks.', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),
            if (!isClient)
              for (final t in s.tasks) ...[
                _TaskCard(task: t),
                const SizedBox(height: 12),
              ]
            else ...[
              for (final c in (s.isLive ? s.clientCategories : MockData.clientCategories).where((c) => c.clientId == e.clientOrgId)) ...[
                _ClientCategoryCard(category: c),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.task});
  final Task task;

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  final _note = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  (String, Color) get _statusStyle => switch (widget.task.status) {
        TaskStatus.done => ('Done', const Color(0xFF16A34A)),
        TaskStatus.ongoing => ('Ongoing', AppColors.primary),
        TaskStatus.blocked => ('Blocked', const Color(0xFFDC2626)),
        TaskStatus.dropped => ('Dropped', AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final (statusLabel, statusColor) = _statusStyle;
    final s = ref.watch(protoStoreProvider);
    final project = _projectName(s, t.projectId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                    child: Icon(
                      t.status == TaskStatus.done
                          ? Icons.check_circle_rounded
                          : t.status == TaskStatus.blocked
                              ? Icons.report_problem_outlined
                              : t.status == TaskStatus.dropped
                                  ? Icons.cancel_outlined
                                  : Icons.radio_button_unchecked_rounded,
                      size: 19,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3)),
                        const SizedBox(height: 3),
                        Text('$project · ${t.subtasks.length} subtask${t.subtasks.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (t.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _Tag(label: statusLabel, color: statusColor),
                      const SizedBox(height: 6),
                      Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.subtasks.isNotEmpty) ...[
                    const Text('Subtasks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    for (final st in t.subtasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(child: Text(st.title, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  // Status selector
                  const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final st in TaskStatus.values)
                        ChoiceChip(
                          label: Text(switch (st) {
                            TaskStatus.ongoing => 'Ongoing',
                            TaskStatus.done => 'Done',
                            TaskStatus.blocked => 'Blocked',
                            TaskStatus.dropped => 'Dropped',
                          }, style: const TextStyle(fontSize: 11)),
                          selected: t.status == st,
                          selectedColor: AppColors.lavender,
                          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: t.status == st ? AppColors.primary : AppColors.textSecondary),
                          side: BorderSide(color: t.status == st ? AppColors.primary : AppColors.border),
                          onSelected: (_) => ref.read(protoStoreProvider.notifier).updateTaskStatus(t.id, st),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress notes
                  if (t.progressNotes.isNotEmpty) ...[
                    const Text('Progress notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    for (final n in t.progressNotes.reversed.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(n, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _note,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            hintText: 'Add a progress note…',
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () {
                          final text = _note.text.trim();
                          if (text.isEmpty) return;
                          ref.read(protoStoreProvider.notifier).addProgressNote(t.id, text);
                          _note.clear();
                        },
                        icon: const Icon(Icons.send_rounded, size: 17),
                        style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(42, 42)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientCategoryCard extends ConsumerWidget {
  const _ClientCategoryCard({required this.category});
  final ClientCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final subs = (s.isLive ? s.clientSubcategories : MockData.clientSubcategories)
        .where((sc) => sc.categoryId == category.id)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.apartment_rounded, size: 19, color: Color(0xFF0284C7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(subs.map((sc) => sc.name).join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile — employee details + shortcuts + simulated sign-out.
class ProtoProfilePage extends ConsumerWidget {
  const ProtoProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(protoStoreProvider);
    final e = s.employee!;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary))),
            ],
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text('Profile', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            const Text('Your account and work preferences.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.lavender,
                    child: Text(initialsOf(e.name), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                  const SizedBox(height: 12),
                  Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('${e.jobTitle} · ${e.department}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(999)),
                    child: Text(e.workArrangement == WorkArrangement.clientSite ? 'Client-site' : 'In-house', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 4),
                    child: Text('Account details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  row('Employee', e.id.toUpperCase()),
                  row('Employer', _orgName(s, e.employerOrgId)),
                  if (e.clientOrgId != null) row('Client', _orgName(s, e.clientOrgId!)),
                  row('Account', 'WorkTrack staff account'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProtoComplaintsPage())),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppDimens.radiusCard), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Complaints', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text('View and reply to your complaints', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (s.unreadComplaintCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(999)),
                          child: Text('${s.unreadComplaintCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: Color(0xFFF0C4C4))),
            ),
          ],
        ),
      ),
    );
  }
}

