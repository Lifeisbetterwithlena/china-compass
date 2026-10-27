import 'package:flutter/material.dart';

import '../theme.dart';
import 'floating_nav.dart';

/// Navigation for wide windows: the same tabs as the floating bar, as a column on the left.
class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.items, required this.index, required this.onTap});

  final List<FloatingNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 26,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('China Compass',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SideItem(item: items[i], active: i == index, onTap: () => onTap(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.item, required this.active, required this.onTap});

  final FloatingNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(active ? item.activeIcon : item.icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
