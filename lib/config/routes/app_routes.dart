import 'package:flutter/material.dart';
import 'package:petit/features/home/presentation/pages/home_screen.dart';
import 'package:petit/features/home/presentation/pages/home_screen_web.dart';
import 'package:petit/features/images/presentation/pages/images_page.dart';
import 'package:petit/features/images/presentation/pages/images_page_web.dart';
import 'package:petit/features/videos/presentation/pages/videos_page.dart';
import 'package:petit/features/videos/presentation/pages/videos_page_web.dart';

class AppRoutes {
  static Route onGenerateRoutes(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _materialRoute(const HomeScreen());

      case '/web':
        return _materialRoute(const HomeScreenWeb());

      case '/images':
        return _materialRoute(const ImagesPage());

      case '/images_web':
        return _materialRoute(const ImagesPageWeb());

      case '/videos':
        return _materialRoute(const VideosPage());

      case '/videos_web':
        return _materialRoute(const VideosPageWeb());
        
      default:
        return _materialRoute(const HomeScreen());
    }
  }

  static Route<dynamic> _materialRoute(Widget view) {
    return MaterialPageRoute(builder: (_) => view);
  }
}