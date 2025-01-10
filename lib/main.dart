import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/home/presentation/pages/home.dart';

import 'config/routes/AppRoutes.dart';
import 'config/theme/AppTheme.dart';

void main() {
  runApp(const SuperApp(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      onGenerateRoute: AppRoutes.onGenerateRoutes,
      home: const HomePage(),
    );
  }
}

