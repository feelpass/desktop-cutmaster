import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'ui/main_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CutmasterApp()));
}

class CutmasterApp extends StatelessWidget {
  const CutmasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: const MainScreen(),
    );
  }
}
