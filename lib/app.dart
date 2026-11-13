import 'package:material_ui/material_ui.dart';

import 'screens/shell.dart';
import 'theme/app_theme.dart';

class ChessYarApp extends StatelessWidget {
  const ChessYarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessYar Professional',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        // The whole UI is Persian (RTL); the chessboard forces LTR internally.
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: const Shell(),
    );
  }
}
