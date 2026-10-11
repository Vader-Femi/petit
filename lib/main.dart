import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:petit/common/data/shared_media_details.dart';
import 'package:petit/core/utils/app_scroll_behavior.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:share_handler/share_handler.dart';
import 'package:petit/features/home/presentation/pages/home_screen.dart';
import 'package:petit/service_locator.dart';
import 'package:upgrader/upgrader.dart';
import 'config/routes/app_routes.dart';
import 'config/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebase();

  try {
    await initializeDependencies();
  } catch (e) {
    if (kDebugMode) {
      print(
          "Failed to init dependencies. Dependencies might already be initialized ${e.toString()}");
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Firebase is not configured for Linux, and Crashlytics has no Windows or
/// Linux implementation, so both are skipped there instead of failing quietly.
Future<void> _initFirebase() async {
  if (PlatformInfo.isLinux) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ONLY set these up after successful init
    if (PlatformInfo.supportsCrashlytics) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e, stack) {
    // If Firebase fails, print to console so you can see it in 'adb logcat'
    debugPrint("Failed to initialize Firebase: $e");
    debugPrint(stack.toString());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<SharedMedia>? _intentStreamSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // Only created where Analytics is supported: touching
  // FirebaseAnalytics.instance without an initialised Firebase app throws.
  static final FirebaseAnalyticsObserver? observer =
      PlatformInfo.supportsAnalytics
          ? FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)
          : null;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  void _initShareHandler() {
    // share_handler has no desktop implementation.
    if (PlatformInfo.isDesktop) return;

    final handler = ShareHandler.instance;

    // Listen for shared media while app is running
    _intentStreamSubscription =
        handler.sharedMediaStream.listen((SharedMedia media) {
      _handleSharedMedia(media);
    });

    // Check for initial shared media (when app is launched via share)
    handler.getInitialSharedMedia().then((SharedMedia? media) {
      if (media != null) {
        _handleSharedMedia(media);
      }
    });
  }

  void _handleSharedMedia(SharedMedia media) {
    // Handle shared content based on what's available
    if (media.attachments != null && media.attachments!.isNotEmpty) {
      // Convert List<Attachment> to List<SharedAttachment>
      List<SharedAttachment> sharedAttachments = media.attachments!
          .map((attachment) => SharedAttachment(
                path: attachment!.path,
                type: attachment.type,
              ))
          .toList();

      _handleAttachments(sharedAttachments);
      return;
    }
    showErrorMessage('Unsupported File');
  }

  void _handleAttachments(List<SharedAttachment> attachments) {
    final images = <SharedAttachment>[];
    final videos = <SharedAttachment>[];

    for (var attachment in attachments) {
      final path = attachment.path;
      if (_isImage(path)) {
        images.add(attachment);
      } else if (_isVideo(path)) {
        videos.add(attachment);
      } else {
        showErrorMessage('Unsupported File');
        return;
      }
    }

    if (images.isNotEmpty && videos.isNotEmpty) {
      // Mixed media not allowed
      showErrorMessage('You can either send pictures, or a single video');
    } else if (videos.length > 1) {
      showErrorMessage('You can only send a single video');
    } else if (images.isNotEmpty) {
      _handleImages(images);
    } else if (videos.isNotEmpty) {
      _handleVideo(videos);
    } else {
      showErrorMessage('Unsupported File');
    }
  }

  bool _isImage(String path) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  bool _isVideo(String path) {
    final videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.wmv',
      '.flv',
      '.webm'
    ];
    return videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  void _handleImages(List<SharedAttachment> images) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            sharedMedia: SharedMediaDetails(
              type: SharedMediaType.image,
              sharedAttachment: images,
            ),
          ),
        ),
        (route) => false,
      );
    });
  }

  void _handleVideo(List<SharedAttachment> video) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            sharedMedia: SharedMediaDetails(
              type: SharedMediaType.video,
              sharedAttachment: video,
            ),
          ),
        ),
        (route) => false,
      );
    });
  }

  void showErrorMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
        debugPrint(message);
      }
    });
  }

  @override
  void dispose() {
    _intentStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightTheme = AppTheme.createLightTheme(lightDynamic);
        final darkTheme = AppTheme.createDarkTheme(darkDynamic);

        return MaterialApp(
          title: 'Petit',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,
          scrollBehavior: const AppScrollBehavior(),
          navigatorKey: navigatorKey,
          navigatorObservers: [if (observer != null) observer!],
          initialRoute: '/',
          onGenerateRoute: AppRoutes.onGenerateRoutes,
          home: PlatformInfo.isIOS
              ? UpgradeAlert(
                  dialogStyle: UpgradeDialogStyle.material,
                  showIgnore: false,
                  showLater: true,
                  upgrader: Upgrader(
                    durationUntilAlertAgain: const Duration(days: 3),
                  ),
                  child: HomeScreen(),
                )
              : HomeScreen(),
        );
      },
    );
  }
}
