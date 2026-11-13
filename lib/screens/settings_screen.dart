import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../services/engine_manager.dart';
import '../state/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    engineManager.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appSettings, engineManager]),
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
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('صدای حرکت مهره‌ها'),
                      subtitle: const Text(
                        'مجموعه صدای شبیه لیچس (سنتزشده محلی): حرکت، گرفتن، کیش، قلعه، ارتقا و پایان بازی.',
                        style: TextStyle(fontSize: 12, color: kTextDim),
                      ),
                      value: appSettings.soundEnabled,
                      activeThumbColor: kGold,
                      onChanged: (v) => appSettings.setSoundEnabled(v),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, size: 18, color: kTextDim),
                      Expanded(
                        child: Slider(
                          value: appSettings.soundVolume,
                          divisions: 10,
                          activeColor: kGold,
                          onChanged: appSettings.soundEnabled
                              ? (v) => appSettings.setSoundVolume(v)
                              : null,
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 18, color: kTextDim),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'موتورهای شطرنج (UCI)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سه موتور داخلی (Stockfish، Berserk، Viridithas) هنگام نصب به‌طور خودکار '
                    'کنار برنامه قرار می‌گیرند. برای استفاده از هر موتور UCI دیگری روی سیستم‌تان، '
                    'مسیر فایل آن را اینجا ثبت کنید.',
                    style: TextStyle(fontSize: 12, color: kTextDim, height: 1.8),
                  ),
                  const SizedBox(height: 10),
                  if (engineManager.all.isEmpty)
                    Text(
                      'در این اجرا هیچ موتوری شناسایی نشد. در نسخه نصب‌شده موتورهای داخلی '
                      'به‌صورت خودکار ظاهر می‌شوند؛ یا یک موتور سفارشی اضافه کنید.',
                      style: TextStyle(fontSize: 12, color: const Color(0xFFE3B341), height: 1.8),
                    )
                  else
                    for (final engine in engineManager.all)
                      _engineTile(context, engine),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _addCustomEngineDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('افزودن موتور سفارشی'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'درباره ChessYar Professional',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نسخه 0.2.1 - ویندوز', style: TextStyle(color: kTextDim)),
                  const SizedBox(height: 8),
                  const Text(
                    'شطر‌یار حرفه‌ای: تحلیل بازی با موتورهای UCI، تخته لیچسی، صداها، تمرین تاکتیک، '
                    'کاوشگر گشایش و بانک اطلاعاتی.',
                    style: TextStyle(height: 1.8),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'مهره‌های صفحه: مجموعه cburnett اثر Colin M.L. Burnett (همان مهره‌های سایت '
                    'لیشس) - جزئیات مجوز در ATTRIBUTION.md.',
                    style: TextStyle(fontSize: 12, color: kTextDim, height: 1.7),
                  ),
                  const SizedBox(height: 12),
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

  // ------------------------------------------------------------------ tiles

  Widget _engineTile(BuildContext context, EngineInfo engine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kNavySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3348)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory, size: 18, color: kGold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(engine.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: engine.builtIn
                            ? kGold.withValues(alpha: 0.14)
                            : const Color(0xFF8CA2AD).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        engine.builtIn ? 'داخلی' : 'سفارشی',
                        style: const TextStyle(fontSize: 10, color: kTextDim),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  engine.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11, color: kTextDim),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'آزمایش اتصال UCI',
            visualDensity: VisualDensity.compact,
            onPressed: () => _testEngine(context, engine),
            icon: const Icon(Icons.play_circle_outline, size: 20, color: kGold),
          ),
          if (!engine.builtIn)
            IconButton(
              tooltip: 'حذف موتور',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await appSettings.removeCustomEngine(engine.id);
                await engineManager.refresh();
              },
              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFE06C5A)),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ logic

  Future<void> _testEngine(BuildContext context, EngineInfo engine) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('در حال آزمایش ${engine.displayName}...'),
          duration: const Duration(seconds: 12),
        ),
      );
    String message;
    try {
      final name = await engineManager.testEngine(engine);
      message = name.isEmpty
          ? 'موتور اجرا شد اما نامی گزارش نکرد.'
          : 'اتصال موفق: $name';
    } on TimeoutException {
      message = 'موتور پاسخ نداد؛ مسیر داده‌شده یک موتور UCI معتبر نیست.';
    } catch (e) {
      message = 'اجرای موتور ممکن نشد: ${e.toString()}';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
  }

  Future<void> _addCustomEngineDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    final argsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن موتور سفارشی (UCI)'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام نمایشی (مثلاً Leela)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pathCtrl,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'مسیر کامل فایل exe',
                  hintText: r'C:\Engines\myengine.exe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: argsCtrl,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'آرگومان‌ها (اختیاری)',
                  hintText: '--threads 2',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final path = pathCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (path.isEmpty || name.isEmpty) {
      _snack('نام و مسیر موتور الزامی است.');
      return;
    }
    if (!File(path).existsSync()) {
      _snack('فایل در مسیر داده‌شده پیدا نشد.');
      return;
    }
    final args = argsCtrl.text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    await appSettings.addCustomEngine(name, path, args);
    await engineManager.refresh();
    _snack('موتور ثبت شد. با دکمه آزمایش، اتصال UCI را بررسی کنید.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  // ---------------------------------------------------------------- widgets

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
                      Flexible(
                        child: Text(
                          theme.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: kTextMain),
                        ),
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
