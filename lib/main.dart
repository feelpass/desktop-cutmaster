import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CutmasterApp()));
}

class CutmasterApp extends StatelessWidget {
  const CutmasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cutmaster',
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Text('Cutmaster — MainScreen 미연결 (Task 11에서 연결)'),
        ),
      ),
    );
  }
}
