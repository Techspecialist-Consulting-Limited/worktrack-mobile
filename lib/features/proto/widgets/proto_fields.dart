import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

/// "9:30" minutes-since-midnight → "9:30 AM".
String fmtTime12(int min) {
  final h = min ~/ 60;
  final m = min % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

class ProtoOption<T> {
  const ProtoOption({required this.value, required this.label, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Compact bottom-sheet picker — white surface, lavender-highlighted selected
/// option, purple check. Returns the chosen value or null when dismissed.
Future<T?> showProtoOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<ProtoOption<T>> options,
  T? selected,
  bool searchable = false,
}) {
  _sheetQuery.clear();
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final query = _sheetQuery.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? options
                : options.where((o) => o.label.toLowerCase().contains(query) || (o.subtitle ?? '').toLowerCase().contains(query)).toList();
            return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop(), color: AppColors.textSecondary),
                ],
              ),
            ),
            if (searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _sheetQuery,
                  onChanged: (_) => setSheet(() {}),
                  autofocus: true,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  for (final o in visible)
                    _OptionTile<T>(
                      option: o,
                      selected: o.value == selected,
                      onTap: () => Navigator.of(ctx).pop(o.value),
                    ),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No matches', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                    ),
                ],
              ),
            ),
          ],
            );
          },
        ),
      ),
    ),
  );
}

/// Shared query controller for option sheets (single sheet open at a time).
final _sheetQuery = TextEditingController();

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});
  final ProtoOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.lavender : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (option.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(option.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_rounded, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled dropdown-style field: label above, white field with optional
/// leading icon, value text and trailing chevron. Opens [showProtoOptionSheet].
class ProtoSelectField<T> extends StatelessWidget {
  const ProtoSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.leadingIcon,
    this.placeholder,
    this.enabled = true,
    this.suffixIcon,
    this.searchable = false,
  });

  final String label;
  final List<ProtoOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final IconData? leadingIcon;
  final String? placeholder;
  final bool enabled;
  final Widget? suffixIcon;
  final bool searchable;

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null;
    final display = hasValue
        ? options.firstWhere((o) => o.value == selected, orElse: () => options.first).label
        : (placeholder ?? 'Select $label');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        Material(
          color: enabled ? Colors.white : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: !enabled
                ? null
                : () async {
                    final v = await showProtoOptionSheet<T>(
                      context,
                      title: label,
                      options: options,
                      selected: selected,
                      searchable: searchable,
                    );
                    if (v != null) onChanged(v);
                  },
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 19, color: enabled ? AppColors.primary : AppColors.textMuted),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                        color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  suffixIcon ??
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section heading used across form screens.
class ProtoSectionLabel extends StatelessWidget {
  const ProtoSectionLabel(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}
