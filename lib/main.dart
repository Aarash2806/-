import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'state/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appSettings.load();
  runApp(const ChessYarApp());
}
