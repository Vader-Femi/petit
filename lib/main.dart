import 'dart:async';
import 'dart:io';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:petit/common/data/shared_media_details.dart';
import 'package:share_handler/share_handler.dart';
import 'package:petit/features/home/Home_screen.dart';
import 'package:petit/service_locator.dart';
import 'package:upgrader/upgrader.dart';
import 'config/routes/App_routes.dart';
import 'config/theme/App_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {

  // This is crucial for correct web routing:
  setUrlStrategy(PathUrlStrategy());

  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  try {
    await initializeDependencies();
  } catch (e) {
    if (kDebugMode) {
      print(
          "Failed to init dependencies. Dependencies might already be initialized ${e.toString()}");
    }
  }

  runApp(const SuperApp(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<SharedMedia>? _intentStreamSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  void _initShareHandler() {
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
          navigatorKey: navigatorKey,
          initialRoute: '/',
          onGenerateRoute: AppRoutes.onGenerateRoutes,
          home: kIsWeb
              ? HomeScreen()
              : Platform.isIOS
              ? UpgradeAlert(
            upgrader: Upgrader(
              dialogStyle: UpgradeDialogStyle.material,
              showIgnore: false,
              showLater: true,
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
