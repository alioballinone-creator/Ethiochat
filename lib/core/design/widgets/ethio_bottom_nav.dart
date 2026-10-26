import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ethio_colors.dart';
import '../ethio_spacing.dart';

class EthioNavItem {
  const EthioNavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      this.badge = 0});
  final IconData icon, activeIcon;
  final String label;
  final int badge;
}

/// The only bottom nav in the app: Chats, Contacts, Discover, Me (in that order).
class EthioBottomNav extends StatelessWidget {
  const EthioBottomNav(
      {super.key,
      required this.index,
      required this.onTap,
      this.items = defaultItems});

  final int index;
  final ValueChanged<int> onTap;
  final List<EthioNavItem> items;

  static const defaultItems = [
    EthioNavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Chats'),
    EthioNavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Contacts'),
    EthioNavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Discover'),
    EthioNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = EthioPalette.of(context);
    final on = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
          color: pal.navBackground,
          border: Border(top: BorderSide(color: pal.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.x2),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: items[i].label,
                  child: InkResponse(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(clipBehavior: Clip.none, children: [
                            AnimatedContainer(
                              duration: Dur.normal,
                              curve: Dur.curve,
                              width: 58,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: i == index
                                    ? EthioColors.goldGradient
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                  i == index
                                      ? items[i].activeIcon
                                      : items[i].icon,
                                  size: 22,
                                  color: i == index
                                      ? EthioColors.black
                                      : pal.textTertiary),
                            ),
                            if (items[i].badge > 0)
                              Positioned(
                                right: -2,
                                top: -4,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 18),
                                  height: 18,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: EthioColors.danger,
                                      borderRadius: BorderRadius.circular(9)),
                                  child: Text(
                                      items[i].badge > 99
                                          ? '99+'
                                          : '${items[i].badge}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 3),
                          Text(items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Poppins',
                                  fontWeight: i == index
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: i == index ? on : pal.textTertiary)),
                        ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
