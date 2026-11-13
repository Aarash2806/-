import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Shown for roadmap sections that are not implemented yet.
/// It states the truth instead of faking a feature.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const ComingSoonScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: kNavyCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3348)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kGold.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: kGold, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'این بخش طبق نقشه راه ۹ مرحله‌ای ChessYar در بیلدهای بعدی فعال می‌شود. '
              'برای دیدن وضعیت واقعی هر بیلد، README-FA.md را در مخزن گیت‌هاب ببینید.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextDim, height: 1.9),
            ),
            const SizedBox(height: 14),
            const Text(
              'هم‌اکنون بخش تحلیل بازی کاملاً فعال است.',
              style: TextStyle(color: kGoldLight, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
