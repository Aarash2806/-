import 'package:material_ui/material_ui.dart';

import '../state/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'تنظیمات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'تم تخته',
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  for (var i = 0; i < kBoardThemes.length; i++)
                    _themeTile(context, kBoardThemes[i], i == appSettings.boardThemeIndex,
                        () => appSettings.setBoardTheme(i)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'صدا',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('صدای حرکت مهره‌ها'),
                subtitle: const Text(
                  'مجموعه صدای لیچس؛ فایل‌های صوتی در بیلد بعدی جای‌گذاری می‌شوند.',
                  style: TextStyle(fontSize: 12, color: kTextDim),
                ),
                value: appSettings.soundEnabled,
                activeThumbColor: kGold,
                onChanged: (v) => appSettings.setSoundEnabled(v),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'درباره ChessYar Professional',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نسخه 0.1.0 - ویندوز', style: TextStyle(color: kTextDim)),
                  SizedBox(height: 8),
                  Text(
                    'شطر‌یار حرفه‌ای: تحلیل بازی، تمرین تاکتیک، کاوشگر گشایش و بانک اطلاعاتی با موتورهای UCI.',
                    style: TextStyle(height: 1.8),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'مهره‌های صفحه: مجموعه cburnett اثر Colin M.L. Burnett (همان مهره‌های سایت لیشس) - جزئیات مجوز در ATTRIBUTION.md.',
                    style: TextStyle(fontSize: 12, color: kTextDim, height: 1.7),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => showAboutDialog(context: context),
                    child: const Text('مجوزهای نرم‌افزاری'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kNavyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3348)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    BoardTheme theme,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kGold : const Color(0xFF2A3348),
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Expanded(child: Container(color: theme.light)),
                  Expanded(child: Container(color: theme.dark)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Container(color: theme.dark)),
                  Expanded(child: Container(color: theme.light)),
                ],
              ),
              Positioned.fill(
                child: Container(
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC0E1420)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check_circle, color: kGold, size: 16),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        theme.name,
                        style: const TextStyle(fontSize: 12, color: kTextMain),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
