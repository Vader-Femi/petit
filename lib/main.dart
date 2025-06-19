import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/home/presentation/pages/home.dart';
import 'package:petit/service_locator.dart';
// import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'config/routes/AppRoutes.dart';
import 'config/theme/AppTheme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
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
  // StreamSubscription? _intentDataStreamSubscription;

  // List<SharedMediaFile>? _sharedFiles;

  @override
  void initState() {
    super.initState();

  //   // When app is in memory
  //   _intentDataStreamSubscription = ReceiveSharingIntent.instance
  //       .getMediaStream()
  //       .listen((List<SharedMediaFile> value) {
  //     setState(() {
  //       _sharedFiles = value;
  //     });
  //   }, onError: (err) {
  //     if (kDebugMode) {
  //       print("getMediaStream error: $err");
  //     }
  //   });
  //
  //   // When app is cold started
  //   ReceiveSharingIntent.instance
  //       .getInitialMedia()
  //       .then((List<SharedMediaFile> value) {
  //     setState(() {
  //       _sharedFiles = value;
  //     });
  //   });
  }

  @override
  void dispose() {
    // _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      onGenerateRoute: AppRoutes.onGenerateRoutes,
      home: HomePage(
          // sharedFiles: _sharedFiles
      ),
    );
  }
}