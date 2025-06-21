import 'package:flutter/material.dart';
import 'package:petit/features/home/Home_screen.dart';
import 'package:petit/features/images/presentation/pages/images_page.dart';
import 'package:petit/features/videos/presentation/pages/Videos_page.dart';

class AppRoutes {
  static Route onGenerateRoutes(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _materialRoute(const HomeScreen());

      case '/Images':
        return _materialRoute(const ImagesPage());

      case '/Videos':
        return _materialRoute(const VideosPage());
        
      default:
        return _materialRoute(const HomeScreen());
    }
  }

  static Route<dynamic> _materialRoute(Widget view) {
    return MaterialPageRoute(builder: (_) => view);
  }
}