import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'coming_soon_screen.dart';
import 'settings_screen.dart';

enum Section { analysis, myGames, tactics, openings, database, position, stats, settings }

class _NavItem {
  final Section section;
  final String label;
  final IconData icon;
  final bool enabled;

  const _NavItem(this.section, this.label, this.icon, {this.enabled = true});
}

const List<_NavItem> _navItems = [
  _NavItem(Section.analysis, 'تحلیل بازی', Icons.analytics),
  _NavItem(Section.myGames, 'بازی‌های من', Icons.folder_open, enabled: false),
  _NavItem(Section.tactics, 'تمرین تاکتیک', Icons.bolt, enabled: false),
  _NavItem(Section.openings, 'کاوشگر گشایش', Icons.explore, enabled: false),
  _NavItem(Section.database, 'بانک اطلاعاتی', Icons.storage, enabled: false),
  _NavItem(Section.position, 'تحلیل موقعیت', Icons.grid_on, enabled: false),
  _NavItem(Section.stats, 'آمار عملکرد', Icons.query_stats, enabled: false),
  _NavItem(Section.settings, 'تنظیمات', Icons.settings),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Section _current = Section.analysis;

  @override
  Widget build(BuildContext context) {
    final item =
        _navItems.firstWhere((n) => n.section == _current, orElse: () => _navItems.first);

    return Scaffold(
      body: Row(
        children: [
          _navPanel(),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_current) {
              Section.analysis => const AnalysisScreen(),
              Section.settings => const SettingsScreen(),
              _ => ComingSoonScreen(title: item.label, icon: item.icon),
            },
          ),
        ],
      ),
    );
  }

  Widget _navPanel() {
    return Container(
      width: 232,
      color: kNavyPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGold.withValues(alpha: 0.14),
                    border: Border.all(color: kGold, width: 1.5),
                  ),
                  child: const Icon(Icons.workspace_premium, color: kGold, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ChessYar',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: kGoldLight,
                        ),
                      ),
                      Text('شطر‌یار حرفه‌ای', style: TextStyle(fontSize: 12, color: kTextDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              children: [
                for (final item in _navItems) _navTile(item),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'نسخه 0.1.0 · Windows',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 11, color: kTextDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(_NavItem item) {
    final selected = _current == item.section;
    final enabled = item.enabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? kGold.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled
              ? () => setState(() => _current = item.section)
              : () => setState(() => _current = item.section),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected
                      ? kGoldLight
                      : (enabled ? kTextMain : kTextDim.withValues(alpha: 0.55)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: selected
                          ? kGoldLight
                          : (enabled ? kTextMain : kTextDim.withValues(alpha: 0.75)),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kNavyCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3A445C), width: 0.8),
                    ),
                    child: const Text(
                      'به‌زودی',
                      style: TextStyle(fontSize: 10, color: kTextDim),
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
