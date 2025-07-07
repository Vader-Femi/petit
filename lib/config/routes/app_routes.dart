import 'package:flutter/material.dart';
import 'package:petit/features/home/home_screen.dart';
import 'package:petit/features/images/presentation/pages/images_page.dart';
import 'package:petit/features/videos/presentation/pages/videos_page.dart';

class AppRoutes {
  static Route onGenerateRoutes(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _materialRoute(const HomeScreen());

      case '/images':
        return _materialRoute(const ImagesPage());

      case '/videos':
        return _materialRoute(const VideosPage());
        
      default:
        return _materialRoute(const HomeScreen());
    }
  }

  static Route<dynamic> _materialRoute(Widget view) {
    return MaterialPageRoute(builder: (_) => view);
  }
}